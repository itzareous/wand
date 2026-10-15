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
                    .frame(width: 560)
            } else {
                OnboardingView(agent: agent)
                    .frame(width: 880, height: 600)
            }
        }
        .onAppear {
            #if DEBUG
            OnboardingSnapshots.runIfRequested(agent: agent)
            #endif
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


struct StatusRow: View {
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
