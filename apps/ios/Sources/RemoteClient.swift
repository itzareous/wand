import Foundation
import Network
import Observation
import RemoteKit
#if canImport(UIKit)
import UIKit
#endif

/// One WebSocket connection to one desktop agent.
@MainActor
@Observable
final class RemoteClient {
    enum State: Equatable {
        case idle
        case needsPairing(message: String?)
        case connecting
        case connected
        case failed(String)
    }

    let agent: DiscoveredAgent
    private(set) var state: State = .idle
    private(set) var status: AgentStatus?
    /// The app in front on the computer and its shortcuts; pushed by the agent on every app switch.
    private(set) var context: AppContext?
    private(set) var lastError: String?

    @ObservationIgnored private var connection: NWConnection?
    @ObservationIgnored private var pendingPairingCode: String?

    init(agent: DiscoveredAgent) {
        self.agent = agent
    }

    func connect(pairingCode: String? = nil) {
        disconnect()
        pendingPairingCode = pairingCode
        guard TokenStore.token(for: agent.name) != nil || pairingCode != nil else {
            state = .needsPairing(message: nil)
            return
        }

        let parameters = NWParameters.tcp
        let webSocket = NWProtocolWebSocket.Options()
        webSocket.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocket, at: 0)
        parameters.includePeerToPeer = true

        let connection = NWConnection(to: agent.endpoint, using: parameters)
        connection.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated { self?.handle(state) }
        }
        self.connection = connection
        state = .connecting
        connection.start(queue: .main)
        receive(on: connection)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }

    func send(_ action: RemoteAction) {
        send(ClientMessage.command(action))
    }

    func run(_ shortcut: ShortcutButton) {
        send(ClientMessage.runShortcut(shortcut.id))
    }

    func type(_ text: String) {
        send(ClientMessage.typeText(text))
    }

    func press(_ key: SpecialKey) {
        send(ClientMessage.pressKey(key))
    }

    func switcher(_ action: SwitcherAction) {
        send(ClientMessage.appSwitcher(action))
    }

    private func handle(_ connectionState: NWConnection.State) {
        switch connectionState {
        case .ready:
            send(.hello(deviceName: Self.deviceName,
                        token: TokenStore.token(for: agent.name),
                        pairingCode: pendingPairingCode))
        case .failed(let error):
            state = .failed(error.localizedDescription)
        case .waiting(let error):
            state = .failed(error.localizedDescription)
        default:
            break
        }
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            MainActor.assumeIsolated {
                guard let self, self.connection === connection else { return }
                if let error {
                    // Agent closed the socket or went away (quit, sleep, Wi-Fi change).
                    if case .needsPairing = self.state {} else { self.state = .failed(error.localizedDescription) }
                    return
                }
                if let data, let message = try? RemoteCoding.decode(ServerMessage.self, from: data) {
                    self.handle(message)
                }
                self.receive(on: connection)
            }
        }
    }

    private func handle(_ message: ServerMessage) {
        switch message.type {
        case .welcome:
            if let token = message.token { TokenStore.save(token, for: agent.name) }
            pendingPairingCode = nil
            state = .connected
        case .rejected:
            TokenStore.remove(for: agent.name)
            disconnect()
            state = .needsPairing(message: message.error ?? "That code didn't work.")
        case .ack:
            lastError = message.ok == false ? message.error : nil
        case .status:
            status = message.status
        case .context:
            context = message.context
        }
    }

    private func send(_ message: ClientMessage) {
        guard let connection, let data = try? RemoteCoding.encode(message) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "message", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }

    private static var deviceName: String {
        #if canImport(UIKit)
        UIDevice.current.name
        #else
        Host.current().localizedName ?? "Device"
        #endif
    }
}
