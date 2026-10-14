import AppKit
import ApplicationServices
import RemoteKit

enum SystemControlError: LocalizedError {
    case needsAccessibility
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .needsAccessibility: "Allow the Remote agent in System Settings → Privacy & Security → Accessibility."
        case .scriptFailed(let message): message
        }
    }
}

/// macOS implementation of every RemoteAction.
/// Media keys are synthesised system events (needs Accessibility permission, works with any player).
/// Volume uses AppleScript's `set volume`, which needs no permission and lets us read the level back.
enum SystemControl {
    // NX_KEYTYPE_* values from IOKit/hidsystem/ev_keymap.h
    private static let keyPlay: Int32 = 16
    private static let keyNext: Int32 = 17
    private static let keyPrevious: Int32 = 18

    private static let volumeStep = 6

    /// Synthesising media keys needs the "post events" grant (listed under Accessibility /
    /// Device Control and Data Access). Check that one directly; AXIsProcessTrusted covers the AX API.
    static var hasAccessibility: Bool { CGPreflightPostEventAccess() }

    static func requestAccessibility() {
        _ = CGRequestPostEventAccess()
    }

    static func perform(_ action: RemoteAction) throws {
        switch action {
        case .playPause: try postMediaKey(keyPlay)
        case .next: try postMediaKey(keyNext)
        case .previous: try postMediaKey(keyPrevious)
        case .volumeUp: try runAppleScript("set volume output volume ((output volume of (get volume settings)) + \(volumeStep)) without output muted")
        case .volumeDown: try runAppleScript("set volume output volume ((output volume of (get volume settings)) - \(volumeStep))")
        case .toggleMute: try runAppleScript("set volume output muted (not (output muted of (get volume settings)))")
        case .lockScreen:
            // Sleeps the display; locks when "Require password immediately" is on (the macOS default).
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["displaysleepnow"]
            try process.run()
        }
    }

    static func status() -> AgentStatus {
        let volume = try? runAppleScript("output volume of (get volume settings)")
        let muted = try? runAppleScript("output muted of (get volume settings)")
        return AgentStatus(
            hostName: Host.current().localizedName ?? "Mac",
            platform: .macOS,
            volume: volume.flatMap { Int($0) },
            muted: muted.map { $0 == "true" }
        )
    }

    private static func postMediaKey(_ key: Int32) throws {
        guard hasAccessibility else { throw SystemControlError.needsAccessibility }
        for isDown in [true, false] {
            let flags = NSEvent.ModifierFlags(rawValue: isDown ? 0xa00 : 0xb00)
            let data1 = Int((key << 16) | ((isDown ? 0xa : 0xb) << 8))
            let event = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: flags,
                                           timestamp: 0, windowNumber: 0, context: nil,
                                           subtype: 8, data1: data1, data2: -1)
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    @discardableResult
    private static func runAppleScript(_ source: String) throws -> String {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            throw SystemControlError.scriptFailed(error[NSAppleScript.errorMessage] as? String ?? "AppleScript failed")
        }
        return result?.stringValue ?? ""
    }
}
