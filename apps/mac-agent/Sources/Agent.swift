import Foundation
import Observation
import RemoteKit

/// Owns the server, the pairing state and the list of trusted phones.
@MainActor
@Observable
final class Agent {
    private(set) var isListening = false
    private(set) var pairingCode = Agent.makePairingCode()
    private(set) var pairedDevices: [String] = []
    private(set) var hasAccessibility = SystemControl.hasAccessibility
    private(set) var lastError: String?

    // TODO(slice: keychain): tokens live in UserDefaults for the foundation slice; move to Keychain.
    private let tokensKey = "pairedTokens"
    private var tokens: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: tokensKey) as? [String: String] ?? [:] }
        set {
            UserDefaults.standard.set(newValue, forKey: tokensKey)
            pairedDevices = newValue.values.sorted()
        }
    }

    @ObservationIgnored private var server: AgentServer?
    @ObservationIgnored let frontmostApp = FrontmostApp()
    @ObservationIgnored let keyboard = KeyboardControl()

    init() {
        pairedDevices = tokens.values.sorted()
        logPairingCode()
        // Ask on first launch so the agent shows up in the Accessibility list without hunting for the .app.
        if !hasAccessibility { SystemControl.requestAccessibility() }
        ShortcutCatalog.validate()
        let server = AgentServer(agent: self)
        self.server = server
        frontmostApp.onChange = { [weak server] context in
            server?.broadcast(ServerMessage(type: .context, context: context))
        }
        keyboard.onSwitcherChange = { [weak self, weak server] in
            guard let self else { return }
            server?.broadcast(ServerMessage(type: .status, status: self.status()))
        }
        server.start()
    }

    func status() -> AgentStatus {
        var status = SystemControl.status()
        status.switcherActive = keyboard.switcherActive
        return status
    }

    /// The phone went away: make sure nothing stays held down.
    func sessionClosed() {
        keyboard.releaseIfNeeded()
    }

    /// Runs a shortcut from the set for the app in front. Uses the context kept current by the activation
    /// notification; NSWorkspace.frontmostApplication goes stale in a background (LSUIElement) app. If the user switched apps since the phone
    /// last got a context, the id won't be in the new set and this throws instead of pressing the wrong keys.
    func runShortcut(id: String) throws {
        guard let definition = ShortcutCatalog.definition(id: id, bundleId: frontmostApp.context.bundleId) else {
            throw SystemControlError.shortcutUnavailable
        }
        try SystemControl.post(definition.combo)
    }

    func setListening(_ listening: Bool, error: String? = nil) {
        isListening = listening
        lastError = error
    }

    func refreshAccessibility() {
        hasAccessibility = SystemControl.hasAccessibility
    }

    /// Returns the token to send back in `welcome`, or nil to reject.
    func authenticate(_ hello: ClientMessage) -> (accepted: Bool, newToken: String?) {
        if let token = hello.token, tokens[token] != nil {
            return (true, nil)
        }
        if let code = hello.pairingCode, code == pairingCode {
            let token = UUID().uuidString + UUID().uuidString
            tokens[token] = hello.deviceName ?? "Phone"
            pairingCode = Agent.makePairingCode() // single use
            logPairingCode()
            return (true, token)
        }
        return (false, nil)
    }

    func forgetAllDevices() {
        tokens = [:]
    }

    /// Debug builds print the code so the agent can be paired from the terminal (tools/remote-cli).
    private func logPairingCode() {
        #if DEBUG
        fputs("Pairing code: \(pairingCode)\n", stderr)
        #endif
    }

    private static func makePairingCode() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
    }
}
