import AppKit
import AVFoundation
import SwiftUI

/// What the person wants Wand for. Decides which onboarding steps they see.
enum WandUsage: String, CaseIterable, Identifiable {
    case remote, dictation, both
    var id: Self { self }
    var usesRemote: Bool { self != .dictation }
    var usesDictation: Bool { self != .remote }
}

/// First-run onboarding: Choose › Set up › Try it. Steps adapt to the chosen usage.
struct OnboardingView: View {
    let agent: Agent

    @State private var usage: WandUsage
    @State private var step: Step
    @State private var goingBack = false

    init(agent: Agent, step: Step = .welcome, usage: WandUsage = .both) {
        self.agent = agent
        _step = State(initialValue: step)
        _usage = State(initialValue: usage)
    }

    enum Step: String, CaseIterable, Hashable {
        case welcome, permissions, micTest, engine, shortcut, pair, tryIt, done

        var section: Int {
            switch self {
            case .welcome: 0
            case .permissions, .micTest, .engine, .shortcut, .pair: 1
            case .tryIt, .done: 2
            }
        }
    }

    private var steps: [Step] {
        var steps: [Step] = [.welcome, .permissions]
        if usage.usesDictation { steps += [.micTest, .engine, .shortcut] }
        if usage.usesRemote { steps.append(.pair) }
        if usage.usesDictation { steps.append(.tryIt) }
        steps.append(.done)
        return steps
    }

    private var progress: Double {
        guard let index = steps.firstIndex(of: step) else { return 0 }
        return Double(index + 1) / Double(steps.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(section: step.section, progress: progress)
            ZStack {
                content
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: goingBack ? .leading : .trailing).combined(with: .opacity),
                        removal: .move(edge: goingBack ? .trailing : .leading).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.snappy(duration: 0.35), value: step)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: WelcomeStep(usage: $usage, onContinue: next)
        case .permissions: PermissionsStep(agent: agent, needsMicrophone: usage.usesDictation, onBack: back, onContinue: next)
        case .micTest: MicTestStep(onBack: back, onContinue: next)
        case .engine: EngineStep(dictation: agent.dictation, onBack: back, onContinue: next)
        case .shortcut: ShortcutStep(onBack: back, onContinue: next)
        case .pair: PairStep(agent: agent, onBack: back, onContinue: next)
        case .tryIt: TryItStep(dictation: agent.dictation, onBack: back, onContinue: next)
        case .done: DoneStep(usage: usage, onBack: back, onFinish: finish)
        }
    }

    private func next() {
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return }
        goingBack = false
        let upcoming = steps[index + 1]
        // Dictation's hotkey goes live for the "try it" step, not before (so testing the key doesn't record).
        if upcoming == .tryIt { agent.dictation.isEnabled = true }
        step = upcoming
    }

    private func back() {
        guard let index = steps.firstIndex(of: step), index > 0 else { return }
        goingBack = true
        step = steps[index - 1]
    }

    private func finish(openAtLogin: Bool) {
        agent.dictation.isEnabled = usage.usesDictation
        UserDefaults.standard.set(usage.rawValue, forKey: "usage")
        agent.setOpensAtLogin(openAtLogin)
        agent.hasCompletedSetup = true
    }
}

// MARK: - Header

private struct OnboardingHeader: View {
    let section: Int
    let progress: Double
    private let titles = ["Choose", "Set up", "Try it"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                ForEach(titles.indices, id: \.self) { index in
                    Text(titles[index])
                        .foregroundStyle(index == section ? .primary : .secondary)
                        .fontWeight(index == section ? .medium : .regular)
                    if index < titles.count - 1 {
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
            }
            .font(.system(size: 14))
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.primary.opacity(0.06))
                    Rectangle().fill(Color.primary.opacity(0.75)).frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 3)
            .animation(.snappy(duration: 0.4), value: progress)
        }
    }
}

// MARK: - Layout

/// Text and actions on the left, an illustration on the right.
private struct SplitStep<Left: View, Right: View>: View {
    var onBack: (() -> Void)?
    @ViewBuilder var left: Left
    @ViewBuilder var right: Right

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                if let onBack {
                    Button(action: onBack) { Label("Back", systemImage: "arrow.left") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 28)
                }
                left
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 36)
            .frame(width: 440, alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .topLeading)

            ZStack { right }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SkyBackground())
                .clipped()
        }
    }
}

/// Soft blue backdrop in the app-icon blue.
private struct SkyBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.86, green: 0.93, blue: 1.0), Color(red: 0.95, green: 0.97, blue: 1.0)],
                       startPoint: .top, endPoint: .bottom)
    }
}

private struct StepTitle: View {
    let title: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.6)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PrimaryButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: .semibold)).lineLimit(1).fixedSize().padding(.horizontal, 22).frame(height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Color.white : Color.secondary)
        .background(Capsule().fill(enabled ? Color.primary : Color.primary.opacity(0.08)))
        .disabled(!enabled)
        .keyboardShortcut(.defaultAction)
    }
}

private struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: .medium)).lineLimit(1).fixedSize().padding(.horizontal, 20).frame(height: 44)
        }
        .buttonStyle(.plain)
        .background(Capsule().strokeBorder(Color.primary.opacity(0.12)))
    }
}

private struct Footer<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            content
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

// MARK: - Welcome

private struct WelcomeStep: View {
    @Binding var usage: WandUsage
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            SkyBackground()
            VStack(spacing: 0) {
                Image("Mascot").resizable().scaledToFit().frame(width: 50)
                Text("Welcome to Wand")
                    .font(.system(size: 28, weight: .bold)).tracking(-0.6)
                    .padding(.top, 12)
                Text("What would you like to use Wand for?")
                    .font(.system(size: 15)).foregroundStyle(.secondary)
                    .padding(.top, 6)

                VStack(spacing: 10) {
                    UsageOption(usage: .both, selected: $usage, symbol: "sparkles", title: "Both",
                                detail: "Control your Mac from your iPhone, and dictate anywhere", badge: "Recommended")
                    UsageOption(usage: .remote, selected: $usage, symbol: "iphone", title: "iPhone remote",
                                detail: "Media, volume, app shortcuts, keyboard and app switching from your phone")
                    UsageOption(usage: .dictation, selected: $usage, symbol: "mic.fill", title: "Dictation",
                                detail: "Hold a key, speak, and Wand types it into any app")
                }
                .padding(.top, 18)

                PrimaryButton(title: "Continue", action: onContinue)
                    .padding(.top, 18)
                Text("You can change this anytime.")
                    .font(.caption).foregroundStyle(.tertiary)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 26)
            .frame(width: 460)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(nsColor: .windowBackgroundColor)))
        }
    }
}

private struct UsageOption: View {
    let usage: WandUsage
    @Binding var selected: WandUsage
    let symbol: String
    let title: String
    let detail: String
    var badge: String?

    private var isSelected: Bool { selected == usage }

    var body: some View {
        Button { selected = usage } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(isSelected ? Color.wandBlue : Color.primary.opacity(0.06)))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 15, weight: .semibold))
                        if let badge {
                            Text(badge).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.wandBlue)
                                .padding(.horizontal, 8).frame(height: 20)
                                .background(Capsule().fill(Color.wandBlue.opacity(0.12)))
                        }
                    }
                    Text(detail).font(.system(size: 12.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(isSelected ? 0.05 : 0.025)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? Color.wandBlue : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isSelected)
    }
}

// MARK: - Permissions

private struct PermissionsStep: View {
    let agent: Agent
    let needsMicrophone: Bool
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var micOK: Bool { micStatus == .authorized }
    private var allGranted: Bool { agent.hasAccessibility && (!needsMicrophone || micOK) }

    var body: some View {
        SplitStep(onBack: onBack) {
            StepTitle(title: "Set up Wand on your Mac", detail: nil)
            VStack(spacing: 10) {
                PermissionCard(
                    title: "Allow Wand to type and press keys",
                    detail: needsMicrophone
                        ? "This lets Wand put your spoken words in the right textbox, and press keys when you tap your iPhone."
                        : "This lets Wand press keys when you tap your iPhone: play/pause, shortcuts, typing.",
                    granted: agent.hasAccessibility
                ) {
                    SystemControl.requestAccessibility()
                    SystemControl.openAccessibilitySettings()
                }
                if needsMicrophone {
                    PermissionCard(
                        title: "Allow Wand to use your microphone",
                        detail: "Wand only listens while you hold the dictation key.",
                        granted: micOK
                    ) {
                        if micStatus == .notDetermined {
                            AVCaptureDevice.requestAccess(for: .audio) { _ in }
                        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            .padding(.top, 26)
            Footer {
                if !allGranted {
                    Button("Skip for now", action: onContinue).buttonStyle(.plain).foregroundStyle(.secondary).padding(.trailing, 6)
                }
                PrimaryButton(title: "Continue", enabled: allGranted, action: onContinue)
            }
        } right: {
            SettingsIllustration(granted: agent.hasAccessibility)
                .padding(40)
        }
        .onReceive(poll) { _ in
            agent.refreshAccessibility()
            micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        }
    }
}

private struct PermissionCard: View {
    let title: String
    let detail: String
    let granted: Bool
    let allow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(title).font(.system(size: 15, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if granted {
                    Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            if !granted {
                Text(detail).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(action: allow) {
                    Text("Allow").font(.system(size: 13, weight: .semibold)).padding(.horizontal, 18).frame(height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(Capsule().fill(Color.primary))
                .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.primary.opacity(0.04)))
        .animation(.snappy(duration: 0.25), value: granted)
    }
}

/// A small drawing of the Accessibility settings page with Wand switched on.
private struct SettingsIllustration: View {
    let granted: Bool

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) { ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0).frame(width: 8, height: 8) } }
                    .padding(.bottom, 8)
                ForEach(["Lock Screen", "Privacy & Security", "Users & Groups", "Keyboard", "Trackpad"], id: \.self) { item in
                    Text(item)
                        .font(.system(size: 10.5))
                        .foregroundStyle(item == "Privacy & Security" ? .white : .secondary)
                        .padding(.horizontal, 6).frame(height: 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 5).fill(item == "Privacy & Security" ? Color.wandBlue : .clear))
                }
                Spacer()
            }
            .padding(12)
            .frame(width: 140)
            .background(Color.primary.opacity(0.04))

            VStack(alignment: .leading, spacing: 10) {
                Text("Accessibility").font(.system(size: 12, weight: .semibold))
                Text("Allow the applications below to control your computer.")
                    .font(.system(size: 9.5)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    WandMark(size: 20)
                    Text("Wand").font(.system(size: 11, weight: .medium))
                    Spacer()
                    Capsule().fill(granted ? Color.wandBlue : Color.primary.opacity(0.15))
                        .frame(width: 30, height: 18)
                        .overlay(Circle().fill(.white).padding(2), alignment: granted ? .trailing : .leading)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                .animation(.snappy, value: granted)
                Spacer()
            }
            .padding(14)
        }
        .frame(width: 380, height: 250)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(nsColor: .windowBackgroundColor)))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Microphone test

/// Reads the microphone level without recording anything.
@MainActor
@Observable
final class MicLevelMonitor {
    private(set) var level: Float = 0
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var running = false

    func start() {
        guard !running, AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { return }
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
            var sum: Float = 0
            for index in 0..<Int(buffer.frameLength) { sum += samples[index] * samples[index] }
            let level = min(1, (sum / Float(buffer.frameLength)).squareRoot() * 14)
            DispatchQueue.main.async { self?.level = level }
        }
        do {
            try engine.start()
            running = true
        } catch {
            input.removeTap(onBus: 0)
        }
    }

    func stop() {
        guard running else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        running = false
        level = 0
    }
}

private struct MicTestStep: View {
    let onBack: () -> Void
    let onContinue: () -> Void
    @State private var monitor = MicLevelMonitor()

    var body: some View {
        SplitStep(onBack: onBack) {
            StepTitle(title: "Speak to test your microphone",
                      detail: "Your Mac's built-in microphone works well. A headset mic works even better in noisy rooms.")
            Text("Do you see the blue bars moving while you speak?")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 40)
            Footer {
                SecondaryButton(title: "Change microphone") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound") { NSWorkspace.shared.open(url) }
                }
                PrimaryButton(title: "Yes, continue", action: onContinue)
            }
        } right: {
            LevelMeter(level: monitor.level)
                .padding(40)
        }
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }
}

private struct LevelMeter: View {
    let level: Float
    private let count = 16

    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<count, id: \.self) { index in
                let lit = Float(index) < level * Float(count)
                Capsule()
                    .fill(lit ? Color.wandBlue : Color.primary.opacity(0.07))
                    .frame(width: 10, height: 40)
            }
        }
        .padding(.horizontal, 26)
        .frame(height: 84)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(nsColor: .windowBackgroundColor)))
        .animation(.easeOut(duration: 0.08), value: level)
    }
}

// MARK: - Engine

private struct EngineStep: View {
    @Bindable var dictation: DictationController
    let onBack: () -> Void
    let onContinue: () -> Void
    @State private var apiKey = ""

    private var ready: Bool { dictation.engine == .onDevice || !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        SplitStep(onBack: onBack) {
            StepTitle(title: "Choose how Wand transcribes",
                      detail: "Cloud is the most accurate and uses your own API key. On this Mac is private and free.")
            VStack(spacing: 10) {
                EngineOption(engine: .cloud, selected: $dictation.engine, title: "Cloud",
                             detail: "OpenAI, Groq, or any OpenAI-compatible server")
                EngineOption(engine: .onDevice, selected: $dictation.engine, title: "On this Mac",
                             detail: "Audio never leaves your Mac. Less accurate with names.")
            }
            .padding(.top, 24)
            if dictation.engine == .cloud {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Provider", selection: $dictation.provider) {
                        ForEach(CloudProvider.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    if dictation.provider == .custom {
                        TextField("API URL", text: $dictation.baseURL, prompt: Text("https://your-server/v1"))
                    }
                    SecureField("API key", text: $apiKey, prompt: Text("Paste your API key (stored in your Keychain)"))
                        .onChange(of: apiKey) { _, value in dictation.apiKey = value }
                }
                .textFieldStyle(.roundedBorder)
                .padding(.top, 14)
            }
            Footer {
                if !ready {
                    Button("Skip for now", action: onContinue).buttonStyle(.plain).foregroundStyle(.secondary).padding(.trailing, 6)
                }
                PrimaryButton(title: "Continue", enabled: ready, action: onContinue)
            }
        } right: {
            VStack(spacing: 18) {
                Image("Mascot").resizable().scaledToFit().frame(width: 120)
                Text(dictation.engine == .cloud ? "Your key, your provider." : "Stays on your Mac.")
                    .font(.system(size: 17, weight: .semibold))
                Text(dictation.engine == .cloud
                     ? "Wand sends your recording straight to the provider you pick. There's no Wand server in between."
                     : "Speech is turned into text by macOS, on this Mac.")
                    .font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .frame(width: 280)
            }
        }
        .onAppear { apiKey = dictation.apiKey }
        .onChange(of: dictation.provider) { _, _ in apiKey = dictation.apiKey }
    }
}

private struct EngineOption: View {
    let engine: DictationEngine
    @Binding var selected: DictationEngine
    let title: String
    let detail: String

    var body: some View {
        Button { selected = engine } label: {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(selected == engine ? Color.wandBlue : Color.primary.opacity(0.2), lineWidth: selected == engine ? 6 : 2)
                    .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold))
                    Text(detail).font(.system(size: 12.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.primary.opacity(0.04)))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: selected)
    }
}

// MARK: - Shortcut test

private struct ShortcutStep: View {
    let onBack: () -> Void
    let onContinue: () -> Void
    @State private var pressed = false
    @State private var seen = false
    @State private var monitor: Any?

    var body: some View {
        SplitStep(onBack: onBack) {
            VStack(alignment: .leading, spacing: 12) {
                (Text("Press to test your shortcut for ").foregroundStyle(.secondary) + Text("Dictate"))
                    .font(.system(size: 30, weight: .bold)).tracking(-0.6)
                    .fixedSize(horizontal: false, vertical: true)
                (Text("Hold the ") + Text("right ⌥ option").fontWeight(.semibold).foregroundStyle(Color.wandBlue)
                    + Text(" key, the one next to the arrow keys."))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(seen ? "Nice, that's the one." : "Do you see the key turning blue while you press it?")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 40)
            Footer {
                if !seen {
                    Button("Skip", action: onContinue).buttonStyle(.plain).foregroundStyle(.secondary).padding(.trailing, 6)
                }
                PrimaryButton(title: "Yes, continue", enabled: seen, action: onContinue)
            }
        } right: {
            KeyboardIllustration(pressed: pressed)
        }
        .onAppear {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                if event.keyCode == DictationController.hotkeyCode {
                    pressed = event.modifierFlags.contains(.option)
                    if pressed { seen = true }
                }
                return event
            }
        }
        .onDisappear { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}

/// The bottom-right corner of a keyboard, with Right Option highlighted when pressed.
private struct KeyboardIllustration: View {
    let pressed: Bool

    var body: some View {
        let key = { (width: CGFloat) in
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12))
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: .windowBackgroundColor)))
                .frame(width: width, height: 46)
        }
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) { key(46); key(46); key(46); key(46); key(46); key(46) }
            HStack(spacing: 7) { key(46); key(46); key(46); key(46); key(46); key(72) }
            HStack(spacing: 7) { key(46); key(46); key(46); key(46); key(98) }
            HStack(spacing: 7) {
                key(120)
                key(46)
                VStack(alignment: .trailing) {
                    Text("⌥").font(.system(size: 15))
                    Spacer()
                    Text("option").font(.system(size: 15, weight: .medium))
                }
                .padding(10)
                .foregroundStyle(pressed ? Color.white : Color.primary)
                .frame(width: 74, height: 58)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(pressed ? Color.wandBlue : Color(nsColor: .windowBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(pressed ? 0 : 0.85), lineWidth: 2))
                .scaleEffect(pressed ? 0.96 : 1)
                key(34)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(nsColor: .windowBackgroundColor).opacity(0.6)))
        .animation(.snappy(duration: 0.12), value: pressed)
    }
}

// MARK: - Pair

private struct PairStep: View {
    let agent: Agent
    let onBack: () -> Void
    let onContinue: () -> Void
    @State private var pairedAtStart = 0

    private var paired: Bool { agent.pairedDevices.count > pairedAtStart }

    var body: some View {
        SplitStep(onBack: onBack) {
            StepTitle(title: "Pair your iPhone",
                      detail: "Open your iPhone's Camera and point it at the code. Wand opens on your phone and pairs by itself.")
            VStack(alignment: .leading, spacing: 8) {
                Text("Or open Wand on your iPhone, tap this Mac and enter:")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                Text(agent.pairingCode)
                    .font(.system(size: 34, weight: .semibold, design: .monospaced))
                    .tracking(4)
                    .textSelection(.enabled)
                    .contentTransition(.numericText())
                Text("Your iPhone and this Mac need to be on the same Wi-Fi.")
                    .font(.system(size: 12)).foregroundStyle(.tertiary)
            }
            .padding(.top, 28)
            if paired {
                Label("iPhone paired", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.system(size: 15, weight: .semibold))
                    .padding(.top, 20)
            }
            Footer {
                if !paired {
                    Button("Skip for now", action: onContinue).buttonStyle(.plain).foregroundStyle(.secondary).padding(.trailing, 6)
                }
                PrimaryButton(title: "Continue", enabled: paired, action: onContinue)
            }
        } right: {
            if let qr = PairingCard.qrImage(agent.pairingURL.absoluteString) {
                Image(nsImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 220, height: 220)
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.white))
                    .overlay(alignment: .bottomTrailing) {
                        Image("Mascot").resizable().scaledToFit().frame(width: 54).offset(x: 22, y: 18)
                    }
            }
        }
        .onAppear { pairedAtStart = agent.pairedDevices.count }
        .onChange(of: agent.pairedDevices.count) { _, _ in
            if paired { DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: onContinue) }
        }
    }
}

// MARK: - Try it

private struct TryItStep: View {
    let dictation: DictationController
    let onBack: () -> Void
    let onContinue: () -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    private let sample = "Wand makes my Mac feel a little bit like magic."
    private var done: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ZStack {
            SkyBackground()
            VStack(spacing: 0) {
                (Text("Now, ").foregroundStyle(.secondary) + Text("dictate"))
                    .font(.system(size: 44, weight: .bold)).tracking(-1)
                Text("Hold the right ⌥ option key, read this out loud, then let go:")
                    .font(.system(size: 15)).foregroundStyle(.secondary)
                    .padding(.top, 10)
                Text("“\(sample)”")
                    .font(.system(size: 19, weight: .medium))
                    .padding(.top, 14)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.system(size: 16))
                        .scrollContentBackground(.hidden)
                        .focused($focused)
                    if text.isEmpty {
                        Text(dictationHint).font(.system(size: 16)).foregroundStyle(.tertiary)
                            .padding(.leading, 5).allowsHitTesting(false)
                    }
                }
                .padding(16)
                .frame(width: 520, height: 130)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(nsColor: .windowBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(done ? Color.green.opacity(0.6) : Color.wandBlue.opacity(0.35), lineWidth: 2))
                .padding(.top, 26)

                HStack(spacing: 10) {
                    if done {
                        Label("That's it, you're dictating!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.system(size: 14, weight: .semibold))
                    }
                }
                .frame(height: 30)
                .padding(.top, 10)

                HStack(spacing: 10) {
                    SecondaryButton(title: "Back", action: onBack)
                    PrimaryButton(title: done ? "Continue" : "Skip", action: onContinue)
                }
                .padding(.top, 8)
            }
        }
        .onAppear { focused = true }
    }

    private var dictationHint: String {
        switch dictation.phase {
        case .recording: "Listening…"
        case .transcribing: "Transcribing…"
        case .failed(let message): message
        case .idle: "Your words will appear here."
        }
    }
}

// MARK: - Done

private struct DoneStep: View {
    let usage: WandUsage
    let onBack: () -> Void
    let onFinish: (_ openAtLogin: Bool) -> Void
    @State private var openAtLogin = true

    var body: some View {
        ZStack {
            SkyBackground()
            VStack(spacing: 0) {
                Image("Mascot").resizable().scaledToFit().frame(width: 84)
                Text("You're all set")
                    .font(.system(size: 34, weight: .bold)).tracking(-0.8)
                    .padding(.top, 18)
                Text("Wand lives in your menu bar.")
                    .font(.system(size: 15)).foregroundStyle(.secondary)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 12) {
                    if usage.usesDictation {
                        Tip(symbol: "mic.fill", text: "Hold the right ⌥ option key anywhere to dictate.")
                    }
                    if usage.usesRemote {
                        Tip(symbol: "iphone", text: "Open Wand on your iPhone to control this Mac.")
                    }
                    Tip(symbol: "menubar.rectangle", text: "Click the Wand icon in the menu bar for settings.")
                }
                .padding(20)
                .frame(width: 400, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(nsColor: .windowBackgroundColor)))
                .padding(.top, 24)

                Toggle("Open Wand when I log in", isOn: $openAtLogin)
                    .toggleStyle(.checkbox)
                    .padding(.top, 20)

                HStack(spacing: 10) {
                    SecondaryButton(title: "Back", action: onBack)
                    PrimaryButton(title: "Start using Wand") { onFinish(openAtLogin) }
                }
                .padding(.top, 20)
            }
        }
    }
}

private struct Tip: View {
    let symbol: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Color.wandBlue).frame(width: 22)
            Text(text).font(.system(size: 14))
        }
    }
}

extension Color {
    /// The app icon's blue.
    static let wandBlue = Color(red: 0, green: 0.53, blue: 0.98)
}

#if DEBUG
/// `-snapshotOnboarding <dir>`: renders every onboarding step to PNGs for design review, then quits.
@MainActor
enum OnboardingSnapshots {
    static func runIfRequested(agent: Agent) {
        guard let dir = UserDefaults.standard.string(forKey: "snapshotOnboarding") else { return }
        for step in OnboardingView.Step.allCases {
            let view = OnboardingView(agent: agent, step: step).frame(width: 880, height: 600)
                .background(Color(nsColor: .windowBackgroundColor))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("onboarding-\(step.rawValue).png"))
            }
        }
        exit(0)
    }
}
#endif
