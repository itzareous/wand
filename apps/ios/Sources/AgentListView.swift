import SwiftUI

struct AgentListView: View {
    @State private var discovery = Discovery()
    @State private var path: [DiscoveredAgent] = []

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
                RemoteScreen(agent: agent)
            }
        }
        .onAppear { discovery.start() }
        .onChange(of: discovery.agents) { _, agents in
            if DebugLaunch.autoOpen, path.isEmpty, let first = agents.first { path = [first] }
        }
    }
}
