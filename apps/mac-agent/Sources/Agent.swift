import Foundation
import Observation
import RemoteKit
import ServiceManagement

struct PairedDevice: Identifiable, Hashable {
    /// The device's token. Never shown in the UI.
    let id: String
    let name: String
}

/// Owns the server, the pairing state, the list of trusted phones and app-level settings.
@MainActor
@Observable
final class Agent {
    private(set) var isListening = false
    private(set) var pairingCode = Agent.makePairingCode()
    private(set) var pairedDevices: [PairedDevice] = []
    /// Tokens of phones connected right now.
    private(set) var connectedTokens: Set<String> = []
    private(set) var hasAccessibility = SystemControl.hasAccessibility
    private(set) var lastError: String?
    private(set) var opensAtLogin = SMAppService.mainApp.status == .enabled
    /// The Bonjour service name; the phone matches on it when pairing from a QR code.
    let serviceName = Host.current().localizedName ?? "Mac"

    var hasCompletedSetup: Bool {
        didSet { UserDefaults.standard.set(hasCompletedSetup, forKey: Self.setupKey) }
    }

    /// What the pairing QR code encodes. The iPhone app handles the `wand://` scheme.
    var pairingURL: URL {
        var components = URLComponents()
        components.scheme = "wand"
        components.host = "pair"
        components.queryItems = [
            URLQueryItem(name: "name", value: serviceName),
            URLQueryItem(name: "code", value: pairingCode),
        ]
        return components.url!
    }

    // TODO(slice: keychain): tokens live in UserDefaults for now; move to Keychain.
    private static let tokensKey = "pairedTokens"
    private static let setupKey = "hasCompletedSetup"
    private var tokens: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: Self.tokensKey) as? [String: String] ?? [:] }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.tokensKey)
            pairedDevices = Self.devices(from: newValue)
        }
    }

    @ObservationIgnored private var server: AgentServer?
    @ObservationIgnored let frontmostApp = FrontmostApp()
    @ObservationIgnored let keyboard = KeyboardControl()
    /// Hold-to-talk dictation into the app in front; independent of pairing.
    @ObservationIgnored let dictation: DictationController
    /// Text copied on this Mac, opened with a double-tap of right ⌥.
    @ObservationIgnored let clipboard = ClipboardHistory()
    @ObservationIgnored private(set) lazy var clipboardPanel = ClipboardPanel(history: clipboard)
    /// Right ⌥: hold to dictate, double-tap for clipboard history.
    @ObservationIgnored let rightOption = RightOptionKey()

    init() {
        dictation = DictationController(keyboard: keyboard)
        hasCompletedSetup = UserDefaults.standard.bool(forKey: Self.setupKey)
        pairedDevices = Self.devices(from: tokens)
        logPairingCode()
        ShortcutCatalog.validate()
        wireRightOption()
        let server = AgentServer(agent: self, serviceName: serviceName)
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

    private func wireRightOption() {
        rightOption.onHoldStart = { [weak self] in
            guard let self, self.dictation.isEnabled else { return }
            if self.clipboardPanel.isVisible { self.clipboardPanel.hide() }
            self.dictation.start()
        }
        rightOption.onHoldEnd = { [weak self] in self?.dictation.stop() }
        rightOption.onCancel = { [weak self] in self?.dictation.cancel() }
        rightOption.onDoubleTap = { [weak self] in
            guard let self, self.clipboard.isEnabled else { return }
            self.clipboardPanel.toggle()
        }
        let update = { [weak self] in
            guard let self else { return }
            self.rightOption.isActive = self.dictation.isEnabled || self.clipboard.isEnabled
        }
        dictation.onEnabledChange = update
        clipboard.onEnabledChange = update
        clipboard.currentAppName = { [weak self] in self?.frontmostApp.context.appName }
        update()
    }

    func status() -> AgentStatus {
        var status = SystemControl.status()
        status.switcherActive = keyboard.switcherActive
        status.dictationReady = dictation.isConfigured
        return status
    }

    // MARK: Sessions

    func sessionOpened(token: String) {
        connectedTokens.insert(token)
    }

    /// The phone went away: make sure nothing stays held down.
    func sessionClosed(token: String?) {
        if let token { connectedTokens.remove(token) }
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

    // MARK: Pairing

    /// Returns the token this session is using (`isNew` when it was just issued for a pairing code), or nil to reject.
    func authenticate(_ hello: ClientMessage) -> (token: String, isNew: Bool)? {
        if let token = hello.token, tokens[token] != nil {
            return (token, false)
        }
        if let code = hello.pairingCode, code == pairingCode {
            let token = UUID().uuidString + UUID().uuidString
            tokens[token] = hello.deviceName ?? "iPhone"
            pairingCode = Agent.makePairingCode() // single use
            logPairingCode()
            return (token, true)
        }
        return nil
    }

    func forget(_ device: PairedDevice) {
        tokens[device.id] = nil
        server?.disconnect(token: device.id)
    }

    func forgetAllDevices() {
        let all = tokens.keys
        tokens = [:]
        all.forEach { server?.disconnect(token: $0) }
    }

    // MARK: Settings and permissions

    func refreshAccessibility() {
        hasAccessibility = SystemControl.hasAccessibility
    }

    func setOpensAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = "Couldn't change Open at Login: \(error.localizedDescription)"
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: Private

    /// Debug builds print the code so the agent can be paired from the terminal (tools/remote-cli).
    private func logPairingCode() {
        #if DEBUG
        fputs("Pairing code: \(pairingCode)\n", stderr)
        #endif
    }

    private static func devices(from tokens: [String: String]) -> [PairedDevice] {
        tokens.map { PairedDevice(id: $0.key, name: $0.value) }.sorted { $0.name < $1.name }
    }

    private static func makePairingCode() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
    }
}
