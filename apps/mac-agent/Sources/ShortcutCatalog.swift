import Carbon.HIToolbox
import CoreGraphics
import RemoteKit

/// A key press with modifiers, posted to whichever app is in front.
struct KeyCombo {
    let key: CGKeyCode
    let flags: CGEventFlags
}

struct ShortcutDefinition {
    let button: ShortcutButton
    let combo: KeyCombo
}

struct ShortcutSet {
    let name: String
    let bundleIds: Set<String>
    let shortcuts: [ShortcutDefinition]
}

/// Per-app shortcut sets. Only each app's stock default shortcuts belong here; if you are
/// not sure a combo is the app's default, leave it out. Ids are "<set>.<action>" and must never change.
enum ShortcutCatalog {
    static func set(for bundleId: String?) -> ShortcutSet {
        guard let bundleId else { return general }
        return sets.first { $0.bundleIds.contains(bundleId) } ?? general
    }

    static func definition(id: String, bundleId: String?) -> ShortcutDefinition? {
        set(for: bundleId).shortcuts.first { $0.button.id == id }
    }

    // MARK: - Sets

    static let general = ShortcutSet(name: "General", bundleIds: [], shortcuts: [
        s("general.missionControl", "Mission Control", "rectangle.3.group", kVK_UpArrow, ctrl),
        s("general.appWindows", "App windows", "macwindow.on.rectangle", kVK_DownArrow, ctrl),
        s("general.previousApp", "Previous app", "arrow.left.arrow.right", kVK_Tab, cmd),
        s("general.spotlight", "Spotlight", "magnifyingglass", kVK_Space, cmd),
        s("general.fullScreen", "Full screen", "arrow.up.left.and.arrow.down.right", kVK_ANSI_F, [cmd, ctrl]),
        s("general.undo", "Undo", "arrow.uturn.backward", kVK_ANSI_Z, cmd),
        s("general.redo", "Redo", "arrow.uturn.forward", kVK_ANSI_Z, [cmd, shift]),
        s("general.closeWindow", "Close window", "xmark", kVK_ANSI_W, cmd),
    ])

    static let sets: [ShortcutSet] = [
        ShortcutSet(name: "Browser", bundleIds: [
            "com.google.Chrome", "com.google.Chrome.canary", "com.apple.Safari", "com.apple.SafariTechnologyPreview",
            "company.thebrowser.Browser", "company.thebrowser.dia", "org.mozilla.firefox", "com.brave.Browser",
            "com.microsoft.edgemac", "com.operasoftware.Opera", "com.vivaldi.Vivaldi",
        ], shortcuts: [
            s("browser.back", "Back", "chevron.left", kVK_ANSI_LeftBracket, cmd),
            s("browser.forward", "Forward", "chevron.right", kVK_ANSI_RightBracket, cmd),
            s("browser.reload", "Refresh", "arrow.clockwise", kVK_ANSI_R, cmd),
            s("browser.newTab", "New tab", "plus", kVK_ANSI_T, cmd),
            s("browser.closeTab", "Close tab", "xmark", kVK_ANSI_W, cmd),
            s("browser.reopenTab", "Reopen tab", "arrow.uturn.backward", kVK_ANSI_T, [cmd, shift]),
            s("browser.previousTab", "Previous tab", "arrow.left.to.line", kVK_Tab, [ctrl, shift]),
            s("browser.nextTab", "Next tab", "arrow.right.to.line", kVK_Tab, ctrl),
            s("browser.addressBar", "Address bar", "link", kVK_ANSI_L, cmd),
            s("browser.find", "Find", "magnifyingglass", kVK_ANSI_F, cmd),
        ]),
        ShortcutSet(name: "Figma", bundleIds: ["com.figma.Desktop"], shortcuts: [
            s("figma.zoomFit", "Zoom to fit", "arrow.up.left.and.arrow.down.right", kVK_ANSI_1, shift),
            s("figma.zoomSelection", "Zoom to selection", "viewfinder", kVK_ANSI_2, shift),
            s("figma.zoomIn", "Zoom in", "plus.magnifyingglass", kVK_ANSI_Equal, cmd),
            s("figma.zoomOut", "Zoom out", "minus.magnifyingglass", kVK_ANSI_Minus, cmd),
            s("figma.frame", "Frame", "number", kVK_ANSI_F, []),
            s("figma.text", "Text", "textformat", kVK_ANSI_T, []),
            s("figma.rectangle", "Rectangle", "rectangle", kVK_ANSI_R, []),
            s("figma.toggleUI", "Hide UI", "sidebar.squares.left", kVK_ANSI_Backslash, cmd),
            s("figma.undo", "Undo", "arrow.uturn.backward", kVK_ANSI_Z, cmd),
            s("figma.redo", "Redo", "arrow.uturn.forward", kVK_ANSI_Z, [cmd, shift]),
        ]),
        ShortcutSet(name: "Code editor", bundleIds: [
            "com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.todesktop.230313mzl4w4u92",
            "com.exafunction.windsurf", "dev.zed.Zed",
        ], shortcuts: [
            s("code.commandPalette", "Commands", "command", kVK_ANSI_P, [cmd, shift]),
            s("code.quickOpen", "Open file", "doc.text.magnifyingglass", kVK_ANSI_P, cmd),
            s("code.terminal", "Terminal", "terminal", kVK_ANSI_Grave, ctrl),
            s("code.sidebar", "Sidebar", "sidebar.left", kVK_ANSI_B, cmd),
            s("code.searchFiles", "Search files", "magnifyingglass", kVK_ANSI_F, [cmd, shift]),
            s("code.save", "Save", "square.and.arrow.down", kVK_ANSI_S, cmd),
            s("code.undo", "Undo", "arrow.uturn.backward", kVK_ANSI_Z, cmd),
            s("code.redo", "Redo", "arrow.uturn.forward", kVK_ANSI_Z, [cmd, shift]),
        ]),
        ShortcutSet(name: "Xcode", bundleIds: ["com.apple.dt.Xcode"], shortcuts: [
            s("xcode.run", "Run", "play.fill", kVK_ANSI_R, cmd),
            s("xcode.stop", "Stop", "stop.fill", kVK_ANSI_Period, cmd),
            s("xcode.build", "Build", "hammer", kVK_ANSI_B, cmd),
            s("xcode.test", "Test", "checkmark.diamond", kVK_ANSI_U, cmd),
            s("xcode.clean", "Clean", "trash", kVK_ANSI_K, [cmd, shift]),
            s("xcode.openQuickly", "Open quickly", "doc.text.magnifyingglass", kVK_ANSI_O, [cmd, shift]),
            s("xcode.navigator", "Navigator", "sidebar.left", kVK_ANSI_0, cmd),
            s("xcode.debugArea", "Debug area", "rectangle.bottomthird.inset.filled", kVK_ANSI_Y, [cmd, shift]),
        ]),
        ShortcutSet(name: "Terminal", bundleIds: [
            "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable",
        ], shortcuts: [
            s("terminal.interrupt", "Stop (⌃C)", "stop.circle", kVK_ANSI_C, ctrl),
            s("terminal.clear", "Clear", "clear", kVK_ANSI_K, cmd),
            s("terminal.newTab", "New tab", "plus", kVK_ANSI_T, cmd),
            s("terminal.closeTab", "Close tab", "xmark", kVK_ANSI_W, cmd),
            s("terminal.previousTab", "Previous tab", "arrow.left.to.line", kVK_ANSI_LeftBracket, [cmd, shift]),
            s("terminal.nextTab", "Next tab", "arrow.right.to.line", kVK_ANSI_RightBracket, [cmd, shift]),
            s("terminal.find", "Find", "magnifyingglass", kVK_ANSI_F, cmd),
        ]),
        ShortcutSet(name: "Slack", bundleIds: ["com.tinyspeck.slackmacgap"], shortcuts: [
            s("slack.jump", "Jump to", "magnifyingglass", kVK_ANSI_K, cmd),
            s("slack.unreads", "All unreads", "tray.full", kVK_ANSI_A, [cmd, shift]),
            s("slack.threads", "Threads", "text.bubble", kVK_ANSI_T, [cmd, shift]),
            s("slack.activity", "Activity", "bell", kVK_ANSI_M, [cmd, shift]),
            s("slack.previousUnread", "Previous unread", "chevron.up", kVK_UpArrow, [opt, shift]),
            s("slack.nextUnread", "Next unread", "chevron.down", kVK_DownArrow, [opt, shift]),
            s("slack.back", "Back", "chevron.left", kVK_ANSI_LeftBracket, cmd),
            s("slack.forward", "Forward", "chevron.right", kVK_ANSI_RightBracket, cmd),
        ]),
        ShortcutSet(name: "Zoom", bundleIds: ["us.zoom.xos"], shortcuts: [
            s("zoom.mute", "Mute", "mic.slash", kVK_ANSI_A, [cmd, shift]),
            s("zoom.video", "Video", "video.slash", kVK_ANSI_V, [cmd, shift]),
            s("zoom.share", "Share screen", "rectangle.on.rectangle", kVK_ANSI_S, [cmd, shift]),
            s("zoom.raiseHand", "Raise hand", "hand.raised", kVK_ANSI_Y, opt),
            s("zoom.chat", "Chat", "bubble.left", kVK_ANSI_H, [cmd, shift]),
            s("zoom.participants", "Participants", "person.2", kVK_ANSI_U, cmd),
        ]),
        ShortcutSet(name: "Teams", bundleIds: ["com.microsoft.teams2"], shortcuts: [
            s("teams.mute", "Mute", "mic.slash", kVK_ANSI_M, [cmd, shift]),
            s("teams.video", "Video", "video.slash", kVK_ANSI_O, [cmd, shift]),
            s("teams.raiseHand", "Raise hand", "hand.raised", kVK_ANSI_K, [cmd, shift]),
        ]),
        ShortcutSet(name: "Finder", bundleIds: ["com.apple.finder"], shortcuts: [
            s("finder.back", "Back", "chevron.left", kVK_ANSI_LeftBracket, cmd),
            s("finder.forward", "Forward", "chevron.right", kVK_ANSI_RightBracket, cmd),
            s("finder.newWindow", "New window", "macwindow.badge.plus", kVK_ANSI_N, cmd),
            s("finder.newFolder", "New folder", "folder.badge.plus", kVK_ANSI_N, [cmd, shift]),
            s("finder.downloads", "Downloads", "arrow.down.circle", kVK_ANSI_L, [cmd, opt]),
            s("finder.desktop", "Desktop", "menubar.dock.rectangle", kVK_ANSI_D, [cmd, shift]),
            s("finder.applications", "Applications", "square.grid.3x3", kVK_ANSI_A, [cmd, shift]),
            s("finder.quickLook", "Quick Look", "eye", kVK_Space, []),
        ]),
        ShortcutSet(name: "Mail", bundleIds: ["com.apple.mail"], shortcuts: [
            s("mail.new", "New", "square.and.pencil", kVK_ANSI_N, cmd),
            s("mail.reply", "Reply", "arrowshape.turn.up.left", kVK_ANSI_R, cmd),
            s("mail.replyAll", "Reply all", "arrowshape.turn.up.left.2", kVK_ANSI_R, [cmd, shift]),
            s("mail.forward", "Forward", "arrowshape.turn.up.right", kVK_ANSI_F, [cmd, shift]),
            s("mail.send", "Send", "paperplane", kVK_ANSI_D, [cmd, shift]),
            s("mail.archive", "Archive", "archivebox", kVK_ANSI_A, [cmd, ctrl]),
            s("mail.getMail", "Get mail", "envelope.arrow.triangle.branch", kVK_ANSI_N, [cmd, shift]),
        ]),
        ShortcutSet(name: "Notion", bundleIds: ["notion.id"], shortcuts: [
            s("notion.search", "Search", "magnifyingglass", kVK_ANSI_P, cmd),
            s("notion.newPage", "New page", "doc.badge.plus", kVK_ANSI_N, cmd),
            s("notion.back", "Back", "chevron.left", kVK_ANSI_LeftBracket, cmd),
            s("notion.forward", "Forward", "chevron.right", kVK_ANSI_RightBracket, cmd),
            s("notion.sidebar", "Sidebar", "sidebar.left", kVK_ANSI_Backslash, cmd),
        ]),
        ShortcutSet(name: "Notes", bundleIds: ["com.apple.Notes"], shortcuts: [
            s("notes.new", "New note", "square.and.pencil", kVK_ANSI_N, cmd),
            s("notes.checklist", "Checklist", "checklist", kVK_ANSI_L, [cmd, shift]),
            s("notes.search", "Search", "magnifyingglass", kVK_ANSI_F, [cmd, opt]),
        ]),
        ShortcutSet(name: "Slides", bundleIds: ["com.apple.iWork.Keynote"], shortcuts: [
            s("keynote.play", "Play", "play.rectangle", kVK_ANSI_P, [cmd, opt]),
            s("keynote.previous", "Previous", "chevron.left", kVK_LeftArrow, []),
            s("keynote.next", "Next", "chevron.right", kVK_RightArrow, []),
            s("keynote.black", "Black screen", "rectangle.fill", kVK_ANSI_B, []),
            s("keynote.exit", "Exit", "xmark", kVK_Escape, []),
        ]),
        ShortcutSet(name: "Slides", bundleIds: ["com.microsoft.Powerpoint"], shortcuts: [
            s("powerpoint.play", "Play", "play.rectangle", kVK_Return, [cmd, shift]),
            s("powerpoint.previous", "Previous", "chevron.left", kVK_LeftArrow, []),
            s("powerpoint.next", "Next", "chevron.right", kVK_RightArrow, []),
            s("powerpoint.black", "Black screen", "rectangle.fill", kVK_ANSI_B, []),
            s("powerpoint.exit", "Exit", "xmark", kVK_Escape, []),
        ]),
        ShortcutSet(name: "Spotify", bundleIds: ["com.spotify.client"], shortcuts: [
            s("spotify.search", "Search", "magnifyingglass", kVK_ANSI_L, cmd),
            s("spotify.shuffle", "Shuffle", "shuffle", kVK_ANSI_S, cmd),
            s("spotify.repeat", "Repeat", "repeat", kVK_ANSI_R, cmd),
            s("spotify.back", "Back", "chevron.left", kVK_ANSI_LeftBracket, cmd),
            s("spotify.forward", "Forward", "chevron.right", kVK_ANSI_RightBracket, cmd),
        ]),
    ]

    // MARK: - Helpers

    private static let cmd = CGEventFlags.maskCommand
    private static let shift = CGEventFlags.maskShift
    private static let ctrl = CGEventFlags.maskControl
    private static let opt = CGEventFlags.maskAlternate

    private static func s(_ id: String, _ title: String, _ symbol: String, _ key: Int, _ flags: CGEventFlags) -> ShortcutDefinition {
        ShortcutDefinition(button: ShortcutButton(id: id, title: title, symbol: symbol),
                           combo: KeyCombo(key: CGKeyCode(key), flags: flags))
    }

    /// Debug check: ids unique and namespaced.
    static func validate() {
        #if DEBUG
        var seen = Set<String>()
        for set in sets + [general] {
            for shortcut in set.shortcuts {
                assert(shortcut.button.id.contains("."), "Shortcut id must be namespaced: \(shortcut.button.id)")
                assert(seen.insert(shortcut.button.id).inserted, "Duplicate shortcut id: \(shortcut.button.id)")
            }
        }
        #endif
    }
}
