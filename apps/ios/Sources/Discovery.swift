import Foundation
import Network
import Observation
import RemoteKit

struct DiscoveredAgent: Identifiable, Hashable {
    let name: String
    let endpoint: NWEndpoint
    var id: String { name }
}

/// Browses the local network for desktop agents advertising RemoteProtocol.bonjourType.
@MainActor
@Observable
final class Discovery {
    private(set) var agents: [DiscoveredAgent] = []
    private(set) var error: String?
    @ObservationIgnored private var browser: NWBrowser?

    func start() {
        guard browser == nil else { return }
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: RemoteProtocol.bonjourType, domain: nil), using: parameters)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            MainActor.assumeIsolated {
                self?.agents = results.compactMap { result in
                    guard case let .service(name, _, _, _) = result.endpoint else { return nil }
                    return DiscoveredAgent(name: name, endpoint: result.endpoint)
                }
                .sorted { $0.name < $1.name }
            }
        }
        browser.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                if case let .failed(error) = state { self?.error = error.localizedDescription }
                // .waiting usually means Local Network permission was denied.
                if case .waiting = state { self?.error = "Allow Local Network access in Settings to find your computer." }
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }
}
