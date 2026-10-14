import Foundation

/// Wire protocol shared by the phone app and every desktop agent.
/// JSON text frames over a WebSocket. See docs/protocol.md — keep the two in sync.
public enum RemoteProtocol {
    public static let version = 1
    /// Bonjour service type the desktop agent advertises (max 15 chars before `._tcp`).
    public static let bonjourType = "_wand._tcp"
}

/// Every action the phone can ask a desktop agent to perform.
/// Raw values are the wire names; the Windows agent must use the same strings.
public enum RemoteAction: String, Codable, CaseIterable, Sendable {
    case playPause = "media.playPause"
    case next = "media.next"
    case previous = "media.previous"
    case volumeUp = "volume.up"
    case volumeDown = "volume.down"
    case toggleMute = "volume.toggleMute"
    case lockScreen = "system.lock"
}

/// Keys the phone can press on the computer (outside of app shortcuts).
public enum SpecialKey: String, Codable, CaseIterable, Sendable {
    case up, down, left, right
    case `return`, escape, tab, delete, space
}

/// Drives the ⌘Tab app switcher: `open` holds ⌘ and shows it, `next`/`previous` move,
/// `choose` releases ⌘ on the selected app, `cancel` closes it without switching.
public enum SwitcherAction: String, Codable, CaseIterable, Sendable {
    case open, next, previous, choose, cancel
}

/// Phone → agent.
public struct ClientMessage: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// First message on every connection. Carries either `token` (already paired)
        /// or `pairingCode` (first-time pairing), plus `deviceName`.
        case hello
        case command
        case statusRequest
        /// Run one of the shortcuts from the agent's latest `context` (by `shortcutId`).
        case runShortcut
        /// Type `text` on the computer as if from a keyboard.
        case typeText
        /// Press `key` once.
        case pressKey
        /// Drive the app switcher with `switcher`.
        case appSwitcher
    }

    public var type: Kind
    public var id: String?
    public var protocolVersion: Int?
    public var deviceName: String?
    public var pairingCode: String?
    public var token: String?
    public var action: RemoteAction?
    public var shortcutId: String?
    public var text: String?
    public var key: SpecialKey?
    public var switcher: SwitcherAction?

    public init(type: Kind, id: String? = nil, protocolVersion: Int? = nil, deviceName: String? = nil,
                pairingCode: String? = nil, token: String? = nil, action: RemoteAction? = nil,
                shortcutId: String? = nil, text: String? = nil, key: SpecialKey? = nil,
                switcher: SwitcherAction? = nil) {
        self.type = type
        self.id = id
        self.protocolVersion = protocolVersion
        self.deviceName = deviceName
        self.pairingCode = pairingCode
        self.token = token
        self.action = action
        self.shortcutId = shortcutId
        self.text = text
        self.key = key
        self.switcher = switcher
    }

    public static func hello(deviceName: String, token: String?, pairingCode: String?) -> ClientMessage {
        ClientMessage(type: .hello, protocolVersion: RemoteProtocol.version, deviceName: deviceName,
                      pairingCode: pairingCode, token: token)
    }

    public static func command(_ action: RemoteAction) -> ClientMessage {
        ClientMessage(type: .command, id: UUID().uuidString, action: action)
    }

    public static func runShortcut(_ shortcutId: String) -> ClientMessage {
        ClientMessage(type: .runShortcut, id: UUID().uuidString, shortcutId: shortcutId)
    }

    public static func typeText(_ text: String) -> ClientMessage {
        ClientMessage(type: .typeText, id: UUID().uuidString, text: text)
    }

    public static func pressKey(_ key: SpecialKey) -> ClientMessage {
        ClientMessage(type: .pressKey, id: UUID().uuidString, key: key)
    }

    public static func appSwitcher(_ action: SwitcherAction) -> ClientMessage {
        ClientMessage(type: .appSwitcher, id: UUID().uuidString, switcher: action)
    }
}

/// Agent → phone.
public struct ServerMessage: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// Hello accepted. `token` is set when this was a first-time pairing — the phone must store it.
        case welcome
        /// Hello refused (bad code / unknown token). The agent closes the connection after sending.
        case rejected
        /// Result of a `command`, echoing its `id`.
        case ack
        /// Pushed after commands and on `statusRequest`.
        case status
        /// Pushed after `welcome` and whenever the frontmost app on the computer changes.
        case context
    }

    public var type: Kind
    public var id: String?
    public var token: String?
    public var ok: Bool?
    public var error: String?
    public var status: AgentStatus?
    public var context: AppContext?

    public init(type: Kind, id: String? = nil, token: String? = nil, ok: Bool? = nil,
                error: String? = nil, status: AgentStatus? = nil, context: AppContext? = nil) {
        self.type = type
        self.id = id
        self.token = token
        self.ok = ok
        self.error = error
        self.status = status
        self.context = context
    }
}

/// The app in front on the computer and the shortcut buttons the agent offers for it.
public struct AppContext: Codable, Equatable, Sendable {
    public var bundleId: String?
    public var appName: String
    /// Small PNG of the app icon.
    public var icon: Data?
    /// Which shortcut set applies, e.g. "Browser", "Figma", "General".
    public var setName: String
    public var shortcuts: [ShortcutButton]

    public init(bundleId: String?, appName: String, icon: Data?, setName: String, shortcuts: [ShortcutButton]) {
        self.bundleId = bundleId
        self.appName = appName
        self.icon = icon
        self.setName = setName
        self.shortcuts = shortcuts
    }
}

/// One button in an AppContext. The agent owns what it does; the phone only sends `id` back.
public struct ShortcutButton: Codable, Equatable, Hashable, Identifiable, Sendable {
    /// Namespaced, stable id, e.g. "browser.back".
    public var id: String
    public var title: String
    /// SF Symbol name.
    public var symbol: String

    public init(id: String, title: String, symbol: String) {
        self.id = id
        self.title = title
        self.symbol = symbol
    }
}

public struct AgentStatus: Codable, Equatable, Sendable {
    public enum Platform: String, Codable, Sendable { case macOS = "macos", windows }

    public var hostName: String
    public var platform: Platform
    /// 0–100, nil when the agent cannot read it.
    public var volume: Int?
    public var muted: Bool?
    /// True while the app switcher is open (⌘ held by the agent).
    public var switcherActive: Bool?

    public init(hostName: String, platform: Platform, volume: Int?, muted: Bool?, switcherActive: Bool? = nil) {
        self.hostName = hostName
        self.platform = platform
        self.volume = volume
        self.muted = muted
        self.switcherActive = switcherActive
    }
}

public enum RemoteCoding {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}
