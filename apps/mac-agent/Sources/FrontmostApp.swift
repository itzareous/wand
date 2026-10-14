import AppKit
import RemoteKit

/// Watches which app is in front and turns it into an AppContext for the phone.
@MainActor
final class FrontmostApp {
    private(set) var context: AppContext
    private var observer: NSObjectProtocol?
    private var iconCache: [String: Data] = [:]

    /// Called on the main actor whenever the frontmost app changes.
    var onChange: ((AppContext) -> Void)?

    init() {
        context = AppContext(bundleId: nil, appName: "Mac", icon: nil, setName: ShortcutCatalog.general.name,
                             shortcuts: ShortcutCatalog.general.shortcuts.map(\.button))
        if let app = NSWorkspace.shared.frontmostApplication { context = makeContext(for: app) }

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let self, let app, app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
                self.context = self.makeContext(for: app)
                self.onChange?(self.context)
            }
        }
    }

    private func makeContext(for app: NSRunningApplication) -> AppContext {
        let set = ShortcutCatalog.set(for: app.bundleIdentifier)
        return AppContext(
            bundleId: app.bundleIdentifier,
            appName: app.localizedName ?? "App",
            icon: icon(for: app),
            setName: set.name,
            shortcuts: set.shortcuts.map(\.button)
        )
    }

    private func icon(for app: NSRunningApplication) -> Data? {
        let key = app.bundleIdentifier ?? app.localizedName ?? ""
        if let cached = iconCache[key] { return cached }
        guard let image = app.icon else { return nil }
        let pixels = 96
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let data = rep.representation(using: .png, properties: [:])
        iconCache[key] = data
        return data
    }
}
