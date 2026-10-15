import AppKit

/// The right Option key, shared by dictation and clipboard history:
/// - hold it (past `holdDelay`) → `onHoldStart`, release → `onHoldEnd`
/// - press another key while holding → `onCancel` (Option was used as a modifier)
/// - tap it twice quickly → `onDoubleTap`
/// Taps never trigger a hold, so the dictation pill doesn't flash on a double-tap.
@MainActor
final class RightOptionKey {
    static let keyCode: UInt16 = 61
    static let name = "Right ⌥ Option"

    var onHoldStart: (() -> Void)?
    var onHoldEnd: (() -> Void)?
    var onCancel: (() -> Void)?
    var onDoubleTap: (() -> Void)?

    /// Monitors run only while something needs the key.
    var isActive = false { didSet { if oldValue != isActive { updateMonitors() } } }

    private let holdDelay: Duration = .milliseconds(180)
    private let doubleTapWindow: TimeInterval = 0.4
    private var monitors: [Any] = []
    private var isDown = false
    private var isHolding = false
    /// Option was combined with another key during this press, so it's neither a tap nor a hold.
    private var usedAsModifier = false
    private var holdTask: Task<Void, Never>?
    private var lastTapEnded: Date?

    private func updateMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        reset()
        guard isActive else { return }
        // Global monitors see other apps' events (needs the Accessibility permission Wand already has);
        // local ones cover Wand's own windows.
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown], handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }) { monitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown], handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
            return event
        }) { monitors.append(monitor) }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged where event.keyCode == Self.keyCode:
            event.modifierFlags.contains(.option) ? pressed() : released()
        case .keyDown where isDown:
            usedAsModifier = true
            holdTask?.cancel()
            if isHolding {
                isHolding = false
                onCancel?()
            }
        default:
            break
        }
    }

    private func pressed() {
        guard !isDown else { return }
        isDown = true
        usedAsModifier = false
        holdTask = Task { [weak self, holdDelay] in
            try? await Task.sleep(for: holdDelay)
            guard let self, !Task.isCancelled, self.isDown, !self.usedAsModifier else { return }
            self.isHolding = true
            self.lastTapEnded = nil
            self.onHoldStart?()
        }
    }

    private func released() {
        guard isDown else { return }
        isDown = false
        holdTask?.cancel()
        if isHolding {
            isHolding = false
            onHoldEnd?()
            return
        }
        guard !usedAsModifier else { return }
        let now = Date()
        if let last = lastTapEnded, now.timeIntervalSince(last) < doubleTapWindow {
            lastTapEnded = nil
            onDoubleTap?()
        } else {
            lastTapEnded = now
        }
    }

    private func reset() {
        holdTask?.cancel()
        isDown = false
        isHolding = false
        lastTapEnded = nil
    }
}
