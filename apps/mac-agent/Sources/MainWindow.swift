import AppKit
import AVFoundation
import SwiftUI

/// The one window Wand has: first-run setup, then the home screen.
struct MainWindow: View {
    static let id = "main"

    let agent: Agent
    let launchedAtLogin: Bool
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Group {
            if agent.hasCompletedSetup {
                HomeView(agent: agent)
            } else {
                SetupView(agent: agent)
            }
        }
        .frame(width: 560)
        .onAppear {
            let open = openWindow
            AppDelegate.openMainWindow = {
                open(id: MainWindow.id)
                NSApp.activate()
            }
            // Started by "Open at Login": stay in the menu bar unless setup still needs finishing.
            if launchedAtLogin && agent.hasCompletedSetup {
                dismissWindow(id: MainWindow.id)
            } else {
                NSApp.activate()
            }
        }
    }
}

// MARK: - Setup

private struct SetupView: View {
    let agent: Agent
    @State private var step: Step = .welcome
    @State private var pairedAtStart = 0
    @State private var openAtLogin = true

    enum Step: Int, CaseIterable { case welcome, permission, pair, done }

    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome: welcome
                case .permission: permission
                case .pair: pair
                case .done: done
                }
            }
            .frame(maxWidth: .infinity, minHeight: 360)
            .padding(.horizontal, 40)
            .padding(.top, 36)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))

            footer
        }
        .animation(.snappy(duration: 0.3), value: step)
        .onAppear { pairedAtStart = agent.pairedDevices.count }
        .onReceive(poll) { _ in agent.refreshAccessibility() }
        .onChange(of: agent.pairedDevices.count) { _, count in
            // A phone just paired with the code on screen: move on by itself.
            if step == .pair, count > pairedAtStart { step = .done }
        }
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            WandMark(size: 72)
            Text("Welcome to Wand")
                .font(.largeTitle.weight(.semibold))
            Text("Control this Mac from your iPhone: play and pause, volume, shortcuts for the app you're using, typing and switching apps.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("Setup takes about a minute.")
                .foregroundStyle(.tertiary)
        }
    }

    private var permission: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeader(number: 1, title: "Let Wand control this Mac",
                       detail: "Wand presses keys for you (play/pause, shortcuts, typing). macOS asks you to allow this once.")
            StatusRow(ok: agent.hasAccessibility,
                      okText: "Allowed. You're good to go.",
                      pendingText: "Not allowed yet")
            if !agent.hasAccessibility {
                VStack(alignment: .leading, spacing: 8) {
                    Button("Open System Settings") {
                        SystemControl.requestAccessibility()
                        SystemControl.openAccessibilitySettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    Text("Turn on **Wand** in Privacy & Security → Accessibility (shown as *Device Control and Data Access* on newer macOS). If Wand isn't listed, click **+** and choose it from Applications. This page updates by itself.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var pair: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeader(number: 2, title: "Pair your iPhone",
                       detail: "Your iPhone and this Mac need to be on the same Wi-Fi.")
            PairingCard(agent: agent)
            Spacer(minLength: 0)
        }
    }

    private var done: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: step)
            Text("You're all set")
                .font(.largeTitle.weight(.semibold))
            Text("Wand lives in your menu bar. Open the Wand app on your iPhone to control this Mac.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Open Wand when I log in", isOn: $openAtLogin)
                .toggleStyle(.checkbox)
                .padding(.top, 8)
        }
    }

    private var footer: some View {
        HStack {
            StepDots(current: step.rawValue, count: Step.allCases.count)
            Spacer()
            if step == .permission || step == .pair {
                Button("Skip") { advance() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
            }
            Button(primaryTitle) { advance() }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(step == .permission && !agent.hasAccessibility)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: "Get Started"
        case .permission, .pair: "Continue"
        case .done: "Done"
        }
    }

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            if next == .pair { pairedAtStart = agent.pairedDevices.count }
            step = next
        } else {
            agent.setOpensAtLogin(openAtLogin)
            agent.hasCompletedSetup = true
        }
    }
}

// MARK: - Home

private struct HomeView: View {
    let agent: Agent
    @State private var showPairing = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    WandMark(size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wand").font(.title2.weight(.semibold))
                        Label(statusText, systemImage: "circle.fill")
                            .labelStyle(StatusDotLabelStyle(color: agent.connectedTokens.isEmpty ? .secondary : .green))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("iPhones") {
                if agent.pairedDevices.isEmpty {
                    Text("No iPhone paired yet.").foregroundStyle(.secondary)
                }
                ForEach(agent.pairedDevices) { device in
                    HStack {
                        Image(systemName: "iphone")
                        Text(device.name)
                        if agent.connectedTokens.contains(device.id) {
                            Text("Connected").font(.caption).foregroundStyle(.green)
                        }
                        Spacer()
                        Button("Forget", role: .destructive) { agent.forget(device) }
                            .buttonBorderShape(.capsule)
                    }
                }
                if showPairing {
                    PairingCard(agent: agent)
                        .padding(.vertical, 8)
                } else {
                    Button("Pair a New iPhone…") { showPairing = true }
                        .buttonBorderShape(.capsule)
                }
            }

            Section("Permissions") {
                HStack {
                    StatusRow(ok: agent.hasAccessibility, okText: "Wand can control this Mac",
                              pendingText: "Wand can't press keys yet")
                    Spacer()
                    if !agent.hasAccessibility {
                        Button("Fix…") {
                            SystemControl.requestAccessibility()
                            SystemControl.openAccessibilitySettings()
                        }
                        .buttonBorderShape(.capsule)
                    }
                }
            }

            DictationSection(dictation: agent.dictation)

            Section("General") {
                Toggle("Open Wand when I log in", isOn: Binding(
                    get: { agent.opensAtLogin },
                    set: { agent.setOpensAtLogin($0) }
                ))
                if let error = agent.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section {
                HStack {
                    Text("Wand \(Bundle.main.shortVersion)").foregroundStyle(.tertiary)
                    Spacer()
                    Button("Quit Wand") { NSApplication.shared.terminate(nil) }
                        .buttonBorderShape(.capsule)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minHeight: 520)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in agent.refreshAccessibility() }
        .onChange(of: agent.pairedDevices.count) { _, _ in showPairing = false }
    }

    private var statusText: String {
        switch agent.connectedTokens.count {
        case 0: agent.isListening ? "Waiting for your iPhone" : "Starting…"
        case 1: "iPhone connected"
        default: "\(agent.connectedTokens.count) iPhones connected"
        }
    }
}

// MARK: - Dictation

private struct DictationSection: View {
    @Bindable var dictation: DictationController
    @State private var apiKeyDraft = ""
    @State private var micStatus = AVCaptureDevice.authorizationStatus(for: .audio)

    var body: some View {
        Section {
            Toggle(isOn: $dictation.isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dictation")
                    Text("Hold \(DictationController.hotkeyName), speak, and let go. Wand types it into the app you're using.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if dictation.isEnabled {
                Picker("Transcription", selection: $dictation.engine) {
                    ForEach(DictationEngine.allCases) { Text($0.title).tag($0) }
                }

                if dictation.engine == .cloud {
                    Picker("Provider", selection: $dictation.provider) {
                        ForEach(CloudProvider.allCases) { Text($0.title).tag($0) }
                    }
                    if dictation.provider == .custom {
                        TextField("API URL", text: $dictation.baseURL, prompt: Text("https://your-server/v1"))
                    }
                    TextField("Model", text: $dictation.model)
                    SecureField("API key", text: $apiKeyDraft, prompt: Text("Stored in your Keychain"))
                        .onChange(of: apiKeyDraft) { _, value in dictation.apiKey = value }
                }

                HStack {
                    Label(micStatus == .authorized ? "Microphone allowed" : "Microphone not allowed yet",
                          systemImage: micStatus == .authorized ? "checkmark.circle.fill" : "mic.slash")
                        .foregroundStyle(micStatus == .authorized ? .green : .secondary)
                    Spacer()
                    if micStatus == .notDetermined {
                        Button("Allow…") { dictation.requestMicrophone() }.buttonBorderShape(.capsule)
                    } else if micStatus != .authorized {
                        Button("Open Settings…") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                        }
                        .buttonBorderShape(.capsule)
                    }
                }

                if case .failed(let message) = dictation.phase {
                    Text(message).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .onAppear { apiKeyDraft = dictation.apiKey }
        .onChange(of: dictation.provider) { _, _ in apiKeyDraft = dictation.apiKey }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        }
    }
}

// MARK: - Pieces

/// The Wand app icon (blue tile with the mascot).
struct WandMark: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size * 1.24, height: size * 1.24) // the icon file has a transparent margin
            .frame(width: size, height: size)
    }
}

private struct StepHeader: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Step \(number) of 2").font(.subheadline).foregroundStyle(.secondary)
            Text(title).font(.title.weight(.semibold))
            Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct StatusRow: View {
    let ok: Bool
    let okText: String
    let pendingText: String

    var body: some View {
        Label(ok ? okText : pendingText, systemImage: ok ? "checkmark.circle.fill" : "circle.dashed")
            .foregroundStyle(ok ? .green : .secondary)
            .contentTransition(.symbolEffect(.replace))
            .animation(.snappy, value: ok)
    }
}

private struct StepDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: index == current ? 18 : 6, height: 6)
            }
        }
        .animation(.snappy, value: current)
    }
}

private struct StatusDotLabelStyle: LabelStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 7)).foregroundStyle(color)
            configuration.title
        }
    }
}

private extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "" }
}
