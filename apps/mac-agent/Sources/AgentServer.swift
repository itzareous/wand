import Foundation
import Network
import RemoteKit

/// WebSocket server advertised over Bonjour. Everything runs on the main queue,
/// which keeps the foundation slice simple; move off-main if command latency shows up.
@MainActor
final class AgentServer {
    private weak var agent: Agent?
    private var listener: NWListener?
    private var sessions: [ObjectIdentifier: ClientSession] = [:]

    init(agent: Agent) {
        self.agent = agent
    }

    func start() {
        let parameters = NWParameters.tcp
        let webSocket = NWProtocolWebSocket.Options()
        webSocket.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocket, at: 0)
        parameters.includePeerToPeer = true

        do {
            let listener = try NWListener(using: parameters)
            listener.service = NWListener.Service(name: Host.current().localizedName ?? "Mac",
                                                  type: RemoteProtocol.bonjourType)
            listener.stateUpdateHandler = { [weak self] state in
                MainActor.assumeIsolated { self?.handle(state) }
            }
            listener.newConnectionHandler = { [weak self] connection in
                MainActor.assumeIsolated { self?.accept(connection) }
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            agent?.setListening(false, error: "Could not start: \(error.localizedDescription)")
        }
    }

    private func handle(_ state: NWListener.State) {
        switch state {
        case .ready: agent?.setListening(true)
        case .failed(let error): agent?.setListening(false, error: error.localizedDescription)
        case .cancelled: agent?.setListening(false)
        default: break
        }
    }

    /// Sends to every paired phone that is connected.
    func broadcast(_ message: ServerMessage) {
        for session in sessions.values where session.isAuthenticated {
            session.send(message)
        }
    }

    private func accept(_ connection: NWConnection) {
        guard let agent else { return connection.cancel() }
        let session = ClientSession(connection: connection, agent: agent) { [weak self] session in
            self?.sessions[ObjectIdentifier(session)] = nil
        }
        sessions[ObjectIdentifier(session)] = session
        session.start()
    }
}

@MainActor
final class ClientSession {
    private let connection: NWConnection
    private let agent: Agent
    private let onClose: (ClientSession) -> Void
    private(set) var isAuthenticated = false

    init(connection: NWConnection, agent: Agent, onClose: @escaping (ClientSession) -> Void) {
        self.connection = connection
        self.agent = agent
        self.onClose = onClose
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self else { return }
                switch state {
                case .failed, .cancelled:
                    self.agent.sessionClosed()
                    self.onClose(self)
                default: break
                }
            }
        }
        connection.start(queue: .main)
        receive()
    }

    private func receive() {
        connection.receiveMessage { [weak self] data, _, _, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if error != nil { return self.connection.cancel() }
                if let data, let message = try? RemoteCoding.decode(ClientMessage.self, from: data) {
                    self.handle(message)
                }
                self.receive()
            }
        }
    }

    private func handle(_ message: ClientMessage) {
        if message.type == .hello {
            let result = agent.authenticate(message)
            guard result.accepted else {
                // Close only after the frame is flushed, or the phone never learns why.
                return send(ServerMessage(type: .rejected, error: "Pairing code or token not recognised"),
                            thenClose: true)
            }
            isAuthenticated = true
            send(ServerMessage(type: .welcome, token: result.newToken))
            send(ServerMessage(type: .status, status: agent.status()))
            send(ServerMessage(type: .context, context: agent.frontmostApp.context))
            return
        }

        guard isAuthenticated else { return connection.cancel() }

        switch message.type {
        case .command:
            guard let action = message.action else {
                return send(ServerMessage(type: .ack, id: message.id, ok: false, error: "Missing action"))
            }
            do {
                try SystemControl.perform(action)
                send(ServerMessage(type: .ack, id: message.id, ok: true))
            } catch {
                send(ServerMessage(type: .ack, id: message.id, ok: false, error: error.localizedDescription))
            }
            send(ServerMessage(type: .status, status: agent.status()))
        case .runShortcut:
            guard let shortcutId = message.shortcutId else {
                return send(ServerMessage(type: .ack, id: message.id, ok: false, error: "Missing shortcutId"))
            }
            do {
                try agent.runShortcut(id: shortcutId)
                send(ServerMessage(type: .ack, id: message.id, ok: true))
            } catch {
                send(ServerMessage(type: .ack, id: message.id, ok: false, error: error.localizedDescription))
            }
        case .typeText, .pressKey, .appSwitcher:
            do {
                switch message.type {
                case .typeText: try agent.keyboard.type(message.text ?? "")
                case .pressKey:
                    guard let key = message.key else { throw SystemControlError.scriptFailed("Missing key") }
                    try agent.keyboard.press(key)
                default:
                    guard let action = message.switcher else { throw SystemControlError.scriptFailed("Missing switcher action") }
                    try agent.keyboard.switcher(action)
                }
                send(ServerMessage(type: .ack, id: message.id, ok: true))
            } catch {
                send(ServerMessage(type: .ack, id: message.id, ok: false, error: error.localizedDescription))
            }
        case .statusRequest:
            send(ServerMessage(type: .status, status: agent.status()))
        case .hello:
            break
        }
    }

    func send(_ message: ServerMessage, thenClose: Bool = false) {
        guard let data = try? RemoteCoding.encode(message) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "message", metadata: [metadata])
        let connection = connection
        connection.send(content: data, contentContext: context, isComplete: true,
                        completion: .contentProcessed { _ in if thenClose { connection.cancel() } })
    }
}
