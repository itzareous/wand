import SwiftUI

struct AgentListView: View {
    @State private var discovery = Discovery()

    var body: some View {
        NavigationStack {
            List {
                if discovery.agents.isEmpty {
                    ContentUnavailableView(
                        "Looking for computers",
                        systemImage: "desktopcomputer",
                        description: Text(discovery.error ?? "Open the Remote agent on your Mac or PC. Both devices need to be on the same Wi-Fi.")
                    )
                }
                ForEach(discovery.agents) { agent in
                    NavigationLink(value: agent) {
                        Label(agent.name, systemImage: "desktopcomputer")
                    }
                }
            }
            .navigationTitle("Remote")
            .navigationDestination(for: DiscoveredAgent.self) { agent in
                RemoteScreen(agent: agent)
            }
        }
        .onAppear { discovery.start() }
    }
}
