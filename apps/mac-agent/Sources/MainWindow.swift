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
                DashboardView(agent: agent)
                    .frame(minWidth: 860, idealWidth: 920, minHeight: 580, idealHeight: 640)
            } else {
                OnboardingView(agent: agent)
                    .frame(width: 880, height: 600)
            }
        }
        .onAppear {
            #if DEBUG
            OnboardingSnapshots.runIfRequested(agent: agent)
            DashboardSnapshots.runIfRequested(agent: agent)
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
