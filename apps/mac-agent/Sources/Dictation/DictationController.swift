import AppKit
import AVFoundation
import Observation

/// Hold Right ⌥ Option to dictate into the app in front. Works with or without a paired phone.
@MainActor
@Observable
final class DictationController {
    enum Phase: Equatable {
        case idle
        case recording
        case transcribing
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    /// Live microphone level while recording, 0…1.
    private(set) var level: Float = 0

    var isEnabled: Bool { didSet { save(isEnabled, Keys.enabled); updateMonitors() } }
    var engine: DictationEngine { didSet { save(engine.rawValue, Keys.engine) } }
    var provider: CloudProvider {
        didSet {
            save(provider.rawValue, Keys.provider)
            baseURL = provider.defaultBaseURL
            model = provider.defaultModel
        }
    }
    var baseURL: String { didSet { save(baseURL, Keys.baseURL) } }
    var model: String { didSet { save(model, Keys.model) } }

    var apiKey: String {
        get { Keychain.string(for: provider.keychainAccount) ?? "" }
        set { Keychain.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), for: provider.keychainAccount) }
    }

    /// Right Option. Rarely used on its own, and holding it alone does nothing in other apps.
    static let hotkeyCode: UInt16 = 61
    static let hotkeyName = "Right ⌥ Option"

    @ObservationIgnored private let keyboard: KeyboardControl
    @ObservationIgnored private let recorder = AudioRecorder()
    @ObservationIgnored private lazy var hud = DictationHUD(controller: self)
    @ObservationIgnored private var monitors: [Any] = []
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    private enum Keys {
        static let enabled = "dictation.enabled"
        static let engine = "dictation.engine"
        static let provider = "dictation.provider"
        static let baseURL = "dictation.baseURL"
        static let model = "dictation.model"
    }

    init(keyboard: KeyboardControl) {
        self.keyboard = keyboard
        let defaults = UserDefaults.standard
        let provider = defaults.string(forKey: Keys.provider).flatMap(CloudProvider.init(rawValue:)) ?? .openAI
        self.provider = provider
        isEnabled = defaults.bool(forKey: Keys.enabled)
        engine = defaults.string(forKey: Keys.engine).flatMap(DictationEngine.init(rawValue:)) ?? .cloud
        baseURL = defaults.string(forKey: Keys.baseURL) ?? provider.defaultBaseURL
        model = defaults.string(forKey: Keys.model) ?? provider.defaultModel
        recorder.onLevel = { [weak self] level in self?.level = level }
        updateMonitors()
    }

    var microphoneStatus: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .audio) }

    func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }

    // MARK: Hotkey

    private func updateMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        guard isEnabled else { return }
        // Global monitors see other apps' events (needs the Accessibility permission Wand already has);
        // local ones cover Wand's own windows.
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown], handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }) { monitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown], handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
            return event
        }) { monitors.append(monitor) }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged where event.keyCode == Self.hotkeyCode:
            if event.modifierFlags.contains(.option) { start() } else { stop() }
        case .keyDown where phase == .recording:
            cancel() // Option was used as a modifier (⌥-shortcut or special character), not to dictate
        default:
            break
        }
    }

    // MARK: Recording

    func start() {
        guard isEnabled, phase != .recording, phase != .transcribing else { return }
        switch microphoneStatus {
        case .authorized: break
        case .notDetermined:
            requestMicrophone()
            return
        default:
            return fail("Allow microphone access for Wand in System Settings → Privacy & Security → Microphone.")
        }
        do {
            try recorder.start()
        } catch {
            return fail("Couldn't start the microphone: \(error.localizedDescription)")
        }
        hideTask?.cancel()
        startedAt = Date()
        level = 0
        phase = .recording
        hud.show()
        NSSound(named: "Tink")?.play()
    }

    func stop() {
        guard phase == .recording, let url = recorder.stop() else { return }
        let duration = Date().timeIntervalSince(startedAt ?? Date())
        guard duration > 0.35 else { // a tap, not a dictation
            try? FileManager.default.removeItem(at: url)
            return finish()
        }
        NSSound(named: "Pop")?.play()
        phase = .transcribing
        let engine = engine, baseURL = baseURL, model = model, apiKey = apiKey
        Task {
            defer { try? FileManager.default.removeItem(at: url) }
            do {
                let text = try await Self.transcribe(url, engine: engine, baseURL: baseURL, model: model, apiKey: apiKey)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { try keyboard.type(trimmed) }
                finish()
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    func cancel() {
        guard phase == .recording else { return }
        if let url = recorder.stop() { try? FileManager.default.removeItem(at: url) }
        finish()
    }

    static func transcribe(_ url: URL, engine: DictationEngine, baseURL: String, model: String, apiKey: String) async throws -> String {
        switch engine {
        case .cloud: try await CloudTranscriber.transcribe(fileAt: url, baseURL: baseURL, model: model, apiKey: apiKey)
        case .onDevice: try await OnDeviceTranscriber.transcribe(fileAt: url)
        }
    }

    private func finish() {
        phase = .idle
        hud.hide()
    }

    private func fail(_ message: String) {
        phase = .failed(message)
        hud.show()
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, case .failed = phase else { return }
            finish()
        }
    }

    private func save(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
