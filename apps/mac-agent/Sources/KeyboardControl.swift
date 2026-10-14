import Carbon.HIToolbox
import CoreGraphics
import Foundation
import RemoteKit

/// Typing, single keys and the ⌘Tab app switcher.
/// The switcher holds ⌘ down across several messages, so it must always be released:
/// on `choose`/`cancel`, on disconnect, and after `idleRelease` without activity.
@MainActor
final class KeyboardControl {
    private(set) var switcherActive = false {
        didSet { if oldValue != switcherActive { onSwitcherChange?() } }
    }
    var onSwitcherChange: (() -> Void)?

    private let idleRelease: TimeInterval = 15
    private var releaseTimer: Timer?
    private let source = CGEventSource(stateID: .hidSystemState)

    func type(_ text: String) throws {
        try requirePermission()
        if switcherActive { try switcher(.cancel) }
        let lines = text.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            if index > 0 { post(CGKeyCode(kVK_Return)) }
            typeUnicode(line)
        }
    }

    func press(_ key: SpecialKey) throws {
        try requirePermission()
        if switcherActive {
            switch key {
            case .return: return try switcher(.choose)
            case .escape: return try switcher(.cancel)
            case .right, .tab: return try switcher(.next)
            case .left: return try switcher(.previous)
            default: break
            }
        }
        post(Self.keyCode(key))
    }

    func switcher(_ action: SwitcherAction) throws {
        try requirePermission()
        switch action {
        case .open:
            if !switcherActive {
                postModifier(CGKeyCode(kVK_Command), down: true, flags: .maskCommand)
                switcherActive = true
            }
            post(CGKeyCode(kVK_Tab), flags: .maskCommand)
        case .next:
            guard switcherActive else { return try switcher(.open) }
            post(CGKeyCode(kVK_Tab), flags: .maskCommand)
        case .previous:
            guard switcherActive else { return try switcher(.open) }
            post(CGKeyCode(kVK_Tab), flags: [.maskCommand, .maskShift])
        case .choose:
            releaseCommand()
        case .cancel:
            if switcherActive { post(CGKeyCode(kVK_Escape), flags: .maskCommand) }
            releaseCommand()
        }
        if switcherActive { restartReleaseTimer() }
    }

    /// Never leave ⌘ held: call when the phone disconnects.
    func releaseIfNeeded() {
        if switcherActive { releaseCommand() }
    }

    // MARK: - Private

    private func releaseCommand() {
        releaseTimer?.invalidate()
        releaseTimer = nil
        guard switcherActive else { return }
        postModifier(CGKeyCode(kVK_Command), down: false, flags: [])
        switcherActive = false
    }

    private func restartReleaseTimer() {
        releaseTimer?.invalidate()
        releaseTimer = Timer.scheduledTimer(withTimeInterval: idleRelease, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.releaseCommand() } // idle: pick whatever is selected
        }
    }

    private func requirePermission() throws {
        guard SystemControl.hasAccessibility else { throw SystemControlError.needsAccessibility }
    }

    private func post(_ key: CGKeyCode, flags: CGEventFlags = []) {
        var flags = flags
        if [kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow].contains(Int(key)) {
            flags.formUnion([.maskSecondaryFn, .maskNumericPad])
        }
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }

    private func postModifier(_ key: CGKeyCode, down: Bool, flags: CGEventFlags) {
        let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)
        event?.type = .flagsChanged
        event?.flags = flags
        event?.post(tap: .cghidEventTap)
    }

    /// Types arbitrary text (any language, emoji) without mapping to physical keys.
    private func typeUnicode(_ text: String) {
        let units = Array(text.utf16)
        var start = 0
        while start < units.count {
            let chunk = Array(units[start..<min(start + 16, units.count)]) // macOS caps one event at ~20 units
            for isDown in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: isDown)
                chunk.withUnsafeBufferPointer { buffer in
                    event?.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
                }
                event?.post(tap: .cghidEventTap)
            }
            start += 16
        }
    }

    private static func keyCode(_ key: SpecialKey) -> CGKeyCode {
        switch key {
        case .up: CGKeyCode(kVK_UpArrow)
        case .down: CGKeyCode(kVK_DownArrow)
        case .left: CGKeyCode(kVK_LeftArrow)
        case .right: CGKeyCode(kVK_RightArrow)
        case .return: CGKeyCode(kVK_Return)
        case .escape: CGKeyCode(kVK_Escape)
        case .tab: CGKeyCode(kVK_Tab)
        case .delete: CGKeyCode(kVK_Delete)
        case .space: CGKeyCode(kVK_Space)
        }
    }
}
