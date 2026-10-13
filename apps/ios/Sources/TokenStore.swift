import Foundation

/// Pairing tokens per agent name.
/// TODO(slice: keychain): UserDefaults for the foundation slice; move to Keychain before TestFlight.
enum TokenStore {
    private static func key(_ agentName: String) -> String { "token.\(agentName)" }

    static func token(for agentName: String) -> String? {
        UserDefaults.standard.string(forKey: key(agentName))
    }

    static func save(_ token: String, for agentName: String) {
        UserDefaults.standard.set(token, forKey: key(agentName))
    }

    static func remove(for agentName: String) {
        UserDefaults.standard.removeObject(forKey: key(agentName))
    }
}
