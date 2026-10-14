import SwiftUI

@main
struct MacAgentApp: App {
    @State private var agent = Agent()

    var body: some Scene {
        MenuBarExtra("Wand", systemImage: "wand.and.sparkles") {
            AgentMenu(agent: agent)
        }
        .menuBarExtraStyle(.window)
    }
}

struct AgentMenu: View {
    let agent: Agent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(agent.isListening ? "Ready on this network" : "Starting…",
                  systemImage: agent.isListening ? "wifi" : "wifi.slash")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Pairing code").font(.caption).foregroundStyle(.secondary)
                Text(agent.pairingCode)
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)
            }

            if !agent.hasAccessibility {
                Button("Allow media keys (Accessibility)…") { SystemControl.requestAccessibility() }
                    .buttonStyle(.borderedProminent)
                    .clipShape(Capsule())
            }

            if !agent.pairedDevices.isEmpty {
                Divider()
                Text("Paired phones").font(.caption).foregroundStyle(.secondary)
                ForEach(agent.pairedDevices, id: \.self) { Text($0) }
                Button("Forget all phones", role: .destructive) { agent.forgetAllDevices() }
            }

            if let error = agent.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding(16)
        .frame(width: 260)
        .onAppear { agent.refreshAccessibility() }
    }
}
