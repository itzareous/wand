import Foundation

/// Wire protocol shared by the phone app and every desktop agent.
/// JSON text frames over a WebSocket. See docs/protocol.md — keep the two in sync.
public enum RemoteProtocol {
    public static let version = 1
    /// Bonjour service type the desktop agent advertises (max 15 chars before `._tcp`).
    public static let bonjourType = "_tbremote._tcp"
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

/// Phone → agent.
public struct ClientMessage: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// First message on every connection. Carries either `token` (already paired)
        /// or `pairingCode` (first-time pairing), plus `deviceName`.
        case hello
        case command
        case statusRequest
    }

    public var type: Kind
    public var id: String?
    public var protocolVersion: Int?
    public var deviceName: String?
    public var pairingCode: String?
    public var token: String?
    public var action: RemoteAction?

    public init(type: Kind, id: String? = nil, protocolVersion: Int? = nil, deviceName: String? = nil,
                pairingCode: String? = nil, token: String? = nil, action: RemoteAction? = nil) {
        self.type = type
        self.id = id
        self.protocolVersion = protocolVersion
        self.deviceName = deviceName
        self.pairingCode = pairingCode
        self.token = token
        self.action = action
    }

    public static func hello(deviceName: String, token: String?, pairingCode: String?) -> ClientMessage {
        ClientMessage(type: .hello, protocolVersion: RemoteProtocol.version, deviceName: deviceName,
                      pairingCode: pairingCode, token: token)
    }

    public static func command(_ action: RemoteAction) -> ClientMessage {
        ClientMessage(type: .command, id: UUID().uuidString, action: action)
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
    }

    public var type: Kind
    public var id: String?
    public var token: String?
    public var ok: Bool?
    public var error: String?
    public var status: AgentStatus?

    public init(type: Kind, id: String? = nil, token: String? = nil, ok: Bool? = nil,
                error: String? = nil, status: AgentStatus? = nil) {
        self.type = type
        self.id = id
        self.token = token
        self.ok = ok
        self.error = error
        self.status = status
    }
}

public struct AgentStatus: Codable, Equatable, Sendable {
    public enum Platform: String, Codable, Sendable { case macOS = "macos", windows }

    public var hostName: String
    public var platform: Platform
    /// 0–100, nil when the agent cannot read it.
    public var volume: Int?
    public var muted: Bool?

    public init(hostName: String, platform: Platform, volume: Int?, muted: Bool?) {
        self.hostName = hostName
        self.platform = platform
        self.volume = volume
        self.muted = muted
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
