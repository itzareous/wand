import RemoteKit
import SwiftUI

/// The Touch Bar–style controls: shortcuts for the app in front, then media, volume and system.
/// Landscape: compact strips. Portrait: a scrolling column.
struct TouchBarView: View {
    let client: RemoteClient
    @State private var tapCount = 0
    @State private var tab: Tab = DebugLaunch.tab.flatMap(Tab.init(rawValue:)) ?? .controls

    enum Tab: String, CaseIterable, Identifiable {
        case controls = "Controls"
        case keyboard = "Keyboard"
        var id: Self { self }
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Mode", selection: $tab) {
                        ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if tab == .keyboard {
                        KeyboardPanel(client: client) { tapCount += 1 }
                    } else {
                        controls(isLandscape: isLandscape)
                    }
                    statusLine
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
    }

    @ViewBuilder private func controls(isLandscape: Bool) -> some View {
        if let context = client.context {
            AppShortcutsView(context: context, isCompact: isLandscape) { shortcut in
                tapCount += 1
                client.run(shortcut)
            }
        }
        if isLandscape {
            HStack(spacing: 10) {
                mediaButtons
                divider
                volumeButtons
                divider
                systemButtons
            }
            .strip()
        } else {
            HStack(spacing: 10) { mediaButtons }.strip()
            HStack(spacing: 10) { volumeButtons }.strip()
            HStack(spacing: 10) { systemButtons }.strip()
        }
    }

    @ViewBuilder private var mediaButtons: some View {
        key("backward.fill", .previous)
        key("playpause.fill", .playPause, prominent: true)
        key("forward.fill", .next)
    }

    @ViewBuilder private var volumeButtons: some View {
        key(client.status?.muted == true ? "speaker.slash.fill" : "speaker.fill", .toggleMute)
        key("speaker.wave.1.fill", .volumeDown)
        key("speaker.wave.3.fill", .volumeUp)
    }

    @ViewBuilder private var systemButtons: some View {
        key("lock.fill", .lockScreen)
    }

    private var divider: some View {
        Capsule().fill(.white.opacity(0.15)).frame(width: 2, height: 28)
    }

    @ViewBuilder private var statusLine: some View {
        if let error = client.lastError {
            Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
        } else if let volume = client.status?.volume {
            Text(client.status?.muted == true ? "Muted" : "Volume \(volume)%")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func key(_ symbol: String, _ action: RemoteAction, prominent: Bool = false) -> some View {
        Button {
            tapCount += 1
            client.send(action)
        } label: {
            Image(systemName: symbol)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(KeyStyle(prominent: prominent))
        .accessibilityLabel(action.rawValue)
    }
}

private struct KeyStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? .black : .white)
            .background(Capsule().fill(prominent ? Color.white : Color.white.opacity(configuration.isPressed ? 0.3 : 0.12)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private extension View {
    func strip() -> some View {
        padding(8).background(Capsule().fill(Color(white: 0.08)))
    }
}
