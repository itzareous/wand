import AppKit
import SwiftUI

@main
struct MacAgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var agent = Agent()

    var body: some Scene {
        Window("Wand", id: MainWindow.id) {
            MainWindow(agent: agent, launchedAtLogin: appDelegate.launchedAtLogin)
                .onAppear { appDelegate.agent = agent }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra("Wand", image: "MenuBarIcon") {
            AgentMenu(agent: agent)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Opens the main window when Wand is launched again while running (Finder, Spotlight, Dock).
final class AppDelegate: NSObject, NSApplicationDelegate {
    var agent: Agent?
    /// Captured from the main window so the window can be reopened from AppKit callbacks.
    static var openMainWindow: (() -> Void)?
    private(set) var launchedAtLogin = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        launchedAtLogin = event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { Self.openMainWindow?() }
        return true
    }
}

struct AgentMenu: View {
    let agent: Agent
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(statusText, systemImage: agent.connectedTokens.isEmpty ? "iphone.slash" : "iphone")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Pairing code").font(.caption).foregroundStyle(.secondary)
                Text(agent.pairingCode)
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)
            }

            if !agent.hasAccessibility {
                Button("Allow Wand to control this Mac…") {
                    SystemControl.requestAccessibility()
                    SystemControl.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }

            if let error = agent.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Divider()
            Button("Open Wand…") {
                openWindow(id: MainWindow.id)
                NSApp.activate()
            }
            Button("Quit Wand") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(.plain)
        .padding(16)
        .frame(width: 260)
        .onAppear { agent.refreshAccessibility() }
    }

    private var statusText: String {
        switch agent.connectedTokens.count {
        case 0: agent.isListening ? "Waiting for your iPhone" : "Starting…"
        case 1: "iPhone connected"
        default: "\(agent.connectedTokens.count) iPhones connected"
        }
    }
}
