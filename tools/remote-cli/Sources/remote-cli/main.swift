import Foundation
import Network
import RemoteKit

// Dev tool: talks to a desktop agent exactly like the phone does.
//   remote-cli list                   agents found on the network
//   remote-cli pair <code>            pair with the first agent found, store the token
//   remote-cli status                 print the agent's status
//   remote-cli context                print the app in front and its shortcut ids
//   remote-cli shortcut <id>          run a shortcut, e.g. browser.reload
//   remote-cli <action>               e.g. media.playPause, volume.up (see docs/protocol.md)
// Token file: ~/.touchbar-remote-cli-token

let tokenURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".touchbar-remote-cli-token")
let arguments = Array(CommandLine.arguments.dropFirst())

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard let command = arguments.first else {
    fail("usage: remote-cli list | pair <code> | status | context | shortcut <id> | <action>\nactions: \(RemoteAction.allCases.map(\.rawValue).joined(separator: ", "))")
}

func browse(timeout: TimeInterval = 4, _ done: @escaping ([NWEndpoint]) -> Void) {
    let browser = NWBrowser(for: .bonjour(type: RemoteProtocol.bonjourType, domain: nil), using: NWParameters())
    var found: [NWEndpoint] = []
    browser.browseResultsChangedHandler = { results, _ in found = results.map(\.endpoint) }
    browser.start(queue: .main)
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
        browser.cancel()
        done(found)
    }
}

func send(_ message: ClientMessage, on connection: NWConnection) {
    let data = try! RemoteCoding.encode(message)
    let context = NWConnection.ContentContext(identifier: "message", metadata: [NWProtocolWebSocket.Metadata(opcode: .text)])
    connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
}

func run(on endpoint: NWEndpoint) {
    let parameters = NWParameters.tcp
    parameters.defaultProtocolStack.applicationProtocols.insert(NWProtocolWebSocket.Options(), at: 0)
    let connection = NWConnection(to: endpoint, using: parameters)

    let token = try? String(contentsOf: tokenURL, encoding: .utf8)
    let pairingCode = command == "pair" ? arguments.dropFirst().first : nil
    if command == "pair" && pairingCode == nil { fail("usage: remote-cli pair <code>") }
    if command != "pair" && token == nil { fail("not paired: run remote-cli pair <code>") }

    connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
            send(.hello(deviceName: "remote-cli", token: pairingCode == nil ? token : nil, pairingCode: pairingCode), on: connection)
        case .failed(let error), .waiting(let error):
            fail("connection: \(error)")
        default: break
        }
    }

    func receive() {
        connection.receiveMessage { data, _, _, error in
            if let error { fail("receive: \(error)") }
            guard let data, let message = try? RemoteCoding.decode(ServerMessage.self, from: data) else { return receive() }
            if message.type == .context, let context = message.context {
                print("< context: \(context.appName) [\(context.bundleId ?? "-")] set=\(context.setName) icon=\(context.icon?.count ?? 0)B")
                context.shortcuts.forEach { print("    \($0.id)  \($0.title)") }
                if command == "context" { exit(0) }
                return receive()
            }
            print("<", String(decoding: data, as: UTF8.self))
            switch message.type {
            case .welcome:
                if let newToken = message.token {
                    try! newToken.write(to: tokenURL, atomically: true, encoding: .utf8)
                    print("paired, token saved")
                }
                if command == "status" || command == "pair" {
                    send(ClientMessage(type: .statusRequest), on: connection)
                } else if command == "context" {
                    break // the agent pushes it after welcome
                } else if command == "shortcut" {
                    guard let id = arguments.dropFirst().first else { fail("usage: remote-cli shortcut <id>") }
                    send(.runShortcut(id), on: connection)
                } else if let action = RemoteAction(rawValue: command) {
                    send(.command(action), on: connection)
                } else {
                    fail("unknown action \(command)")
                }
            case .rejected:
                fail("rejected")
            case .status where command == "status" || command == "pair":
                exit(0)
            case .status, .context:
                break
            case .ack:
                if message.ok == true { exit(0) } else { fail("action failed") }
            }
            receive()
        }
    }

    connection.start(queue: .main)
    receive()
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) { fail("timed out") }
}

browse { endpoints in
    if command == "list" {
        endpoints.forEach { print($0) }
        exit(endpoints.isEmpty ? 1 : 0)
    }
    guard let first = endpoints.first else { fail("no agent found on the network") }
    run(on: first)
}

dispatchMain()
