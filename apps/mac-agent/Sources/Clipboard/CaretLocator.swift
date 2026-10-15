import AppKit
import ApplicationServices

/// Finds the text cursor in whatever app is in front, using the Accessibility API Wand already has
/// permission for. Returns a rect in Cocoa screen coordinates (origin bottom-left), or nil when the app
/// doesn't expose its caret (some Electron and custom-drawn apps).
enum CaretLocator {
    static func caretRect() -> NSRect? {
        let system = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused, CFGetTypeID(element) == AXUIElementGetTypeID() else { return nil }
        let field = element as! AXUIElement

        var rangeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let range = rangeValue else { return nil }

        var boundsValue: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(field, kAXBoundsForRangeParameterizedAttribute as CFString,
                                                         range, &boundsValue) == .success,
              let bounds = boundsValue, CFGetTypeID(bounds) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(bounds as! AXValue, .cgRect, &rect), rect.height > 0 || rect.width > 0 else { return nil }

        // Accessibility uses top-left origin on the primary screen; Cocoa uses bottom-left.
        guard let primary = NSScreen.screens.first else { return nil }
        let flippedY = primary.frame.maxY - rect.maxY
        let result = NSRect(x: rect.minX, y: flippedY, width: max(rect.width, 1), height: max(rect.height, 16))
        // Some apps report (0,0) when they have no real caret.
        return result.origin == .zero ? nil : result
    }
}

#if DEBUG
extension CaretLocator {
    /// `-printCaret YES`: logs the detected caret to stderr every 2 s (for testing in other apps).
    @MainActor
    static func startDebugLogging() {
        guard UserDefaults.standard.bool(forKey: "printCaret") else { return }
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            let app = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
            fputs("caret in \(app): \(caretRect().map { NSStringFromRect($0) } ?? "nil")  mouse: \(NSStringFromPoint(NSEvent.mouseLocation))\n", stderr)
        }
    }
}
#endif
