import Foundation

/// Simulator/UI-test hooks, debug builds only. Pass as launch arguments:
///   -autoOpen YES          open the first computer found
///   -pairingCode 123456    pair with this code instead of asking
///   -tab Keyboard          start on the Keyboard tab
enum DebugLaunch {
    #if DEBUG
    static var autoOpen: Bool { UserDefaults.standard.bool(forKey: "autoOpen") }
    static var pairingCode: String? { UserDefaults.standard.string(forKey: "pairingCode") }
    static var tab: String? { UserDefaults.standard.string(forKey: "tab") }
    #else
    static let autoOpen = false
    static let pairingCode: String? = nil
    static let tab: String? = nil
    #endif
}
