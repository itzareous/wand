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

@Test func runShortcutWireFormat() throws {
    var message = ClientMessage.runShortcut("browser.back")
    message.id = "1"
    let json = String(decoding: try RemoteCoding.encode(message), as: UTF8.self)
    #expect(json == #"{"id":"1","shortcutId":"browser.back","type":"runShortcut"}"#)
}

@Test func contextRoundTrip() throws {
    let context = AppContext(bundleId: "com.figma.Desktop", appName: "Figma", icon: Data([1, 2, 3]), setName: "Figma",
                             shortcuts: [ShortcutButton(id: "figma.zoomFit", title: "Zoom to fit", symbol: "arrow.up.left.and.arrow.down.right")])
    let message = ServerMessage(type: .context, context: context)
    let decoded = try RemoteCoding.decode(ServerMessage.self, from: RemoteCoding.encode(message))
    #expect(decoded == message)
}

@Test func oldMessagesStillDecode() throws {
    // A v1 agent's command ack has no context/shortcut fields.
    let data = Data(#"{"id":"1","ok":true,"type":"ack"}"#.utf8)
    #expect(try RemoteCoding.decode(ServerMessage.self, from: data).ok == true)
}

@Test func keyboardWireFormats() throws {
    func json(_ message: ClientMessage) throws -> String {
        var message = message
        message.id = "1"
        return String(decoding: try RemoteCoding.encode(message), as: UTF8.self)
    }
    #expect(try json(.typeText("hi")) == #"{"id":"1","text":"hi","type":"typeText"}"#)
    #expect(try json(.pressKey(.return)) == #"{"id":"1","key":"return","type":"pressKey"}"#)
    #expect(try json(.appSwitcher(.next)) == #"{"id":"1","switcher":"next","type":"appSwitcher"}"#)
}
