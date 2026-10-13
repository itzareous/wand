import Foundation
import Testing
@testable import RemoteKit

@Test func commandWireFormat() throws {
    var message = ClientMessage.command(.playPause)
    message.id = "1"
    let json = String(decoding: try RemoteCoding.encode(message), as: UTF8.self)
    #expect(json == #"{"action":"media.playPause","id":"1","type":"command"}"#)
}

@Test func serverMessageRoundTrip() throws {
    let message = ServerMessage(type: .status, status: AgentStatus(hostName: "Mac", platform: .macOS, volume: 40, muted: false))
    let decoded = try RemoteCoding.decode(ServerMessage.self, from: RemoteCoding.encode(message))
    #expect(decoded == message)
}

@Test func bonjourTypeFitsLimit() {
    let name = RemoteProtocol.bonjourType.dropFirst().split(separator: ".").first!
    #expect(name.count <= 15)
}
