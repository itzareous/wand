import RemoteKit
import SwiftUI

/// Connects to one agent and shows pairing or the touch bar.
struct RemoteScreen: View {
    @State private var client: RemoteClient
    @State private var code = ""

    /// Pair with this code right away (from a scanned QR) instead of asking.
    private let pairingCode: String?

    init(agent: DiscoveredAgent, pairingCode: String? = nil) {
        _client = State(initialValue: RemoteClient(agent: agent))
        self.pairingCode = pairingCode
    }

    var body: some View {
        Group {
            switch client.state {
            case .idle, .connecting:
                ProgressView("Connecting…")
            case .needsPairing(let message):
                pairing(message: message)
            case .connected:
                TouchBarView(client: client)
            case .failed(let error):
                ContentUnavailableView {
                    Label("Can't reach \(client.agent.name)", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try again") { client.connect() }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                }
            }
        }
        .navigationTitle(client.agent.name)
        .onAppear { client.connect(pairingCode: pairingCode) }
        .onDisappear { client.disconnect() }
    }

    private func pairing(message: String?) -> some View {
        VStack(spacing: 16) {
            Text("Enter the 6-digit code shown in the Wand menu on \(client.agent.name).")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            TextField("000000", text: $code)
                .font(.system(size: 34, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            if let message {
                Text(message).font(.footnote).foregroundStyle(.red)
            }
            Button("Pair") { client.connect(pairingCode: code) }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(code.count != 6)
        }
        .padding(24)
    }
}
