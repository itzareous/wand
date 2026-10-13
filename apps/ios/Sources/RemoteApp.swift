import SwiftUI

@main
struct RemoteApp: App {
    var body: some Scene {
        WindowGroup {
            AgentListView()
                .preferredColorScheme(.dark)
        }
    }
}
