import SwiftUI

struct AgentListView: View {
    /// Opens the computer named in a scanned QR as soon as it has been discovered.
    @discardableResult
    private func openPendingPair() -> Bool {
        guard let pending = pendingPair,
              let agent = discovery.agents.first(where: { $0.name == pending.name }) else { return false }
        pendingPair = nil
        pairingCodes[agent.name] = pending.code
        path = [agent]
        return true
    }

    @State private var discovery = Discovery()
    @State private var path: [DiscoveredAgent] = []
    /// From a scanned pairing QR (`wand://pair?name=…&code=…`), waiting for that computer to be discovered.
    @State private var pendingPair: (name: String, code: String)?
    /// Codes to use when opening an agent, keyed by agent name.
    @State private var pairingCodes: [String: String] = [:]

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if discovery.agents.isEmpty {
                    ContentUnavailableView(
                        "Looking for computers",
                        systemImage: "desktopcomputer",
                        description: Text(discovery.error ?? "Open Wand on your Mac or PC. Both devices need to be on the same Wi-Fi.")
                    )
                }
                ForEach(discovery.agents) { agent in
                    NavigationLink(value: agent) {
                        Label(agent.name, systemImage: "desktopcomputer")
                    }
                }
            }
            .navigationTitle("Wand")
            .navigationDestination(for: DiscoveredAgent.self) { agent in
                RemoteScreen(agent: agent, pairingCode: pairingCodes[agent.name] ?? DebugLaunch.pairingCode)
            }
        }
        .onAppear { discovery.start() }
        .onChange(of: discovery.agents) { _, agents in
            if openPendingPair() { return }
            if DebugLaunch.autoOpen, path.isEmpty, let first = agents.first { path = [first] }
        }
        .onOpenURL { url in
            guard url.scheme == "wand", url.host == "pair",
                  let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                  let name = items.first(where: { $0.name == "name" })?.value,
                  let code = items.first(where: { $0.name == "code" })?.value else { return }
            pendingPair = (name, code)
            _ = openPendingPair()
        }
    }
}
