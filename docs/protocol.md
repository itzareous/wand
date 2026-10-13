# Wire protocol v1

Source of truth in code: `packages/RemoteKit/Sources/RemoteKit/RemoteProtocol.swift`. Change both together.

## Transport
- The desktop agent advertises Bonjour/mDNS service **`_tbremote._tcp`**, named after the computer.
- The phone connects with a **WebSocket** (Network.framework) and sends **one JSON object per text frame**.
- Plain WebSocket on the LAN for v1. TLS is on the roadmap.

## Handshake
1. The phone sends `hello` first, every time.
   - Already paired: `{"type":"hello","protocolVersion":1,"deviceName":"Areous's iPhone","token":"…"}`
   - First time: `{"type":"hello","protocolVersion":1,"deviceName":"…","pairingCode":"123456"}`. The code is shown in the agent's menu.
2. The agent replies with one of:
   - `{"type":"welcome","token":"…"}`: `token` is only present after first-time pairing, and the phone must store it.
     The pairing code then rotates (it works once only).
   - `{"type":"rejected","error":"…"}`: the agent closes the socket. The phone deletes any stored token and asks for a code.
3. After `welcome` the agent pushes a `status`.

Any non-`hello` message before `welcome` makes the agent close the connection.

## Commands
Phone: `{"type":"command","id":"<uuid>","action":"media.playPause"}`
Agent: `{"type":"ack","id":"<same uuid>","ok":true}` (or `"ok":false,"error":"…"`), followed by a fresh `status`.

| action | meaning |
|---|---|
| `media.playPause` | system play/pause key (whatever app is playing) |
| `media.next` / `media.previous` | next / previous track keys |
| `volume.up` / `volume.down` | output volume ±6 |
| `volume.toggleMute` | toggle output mute |
| `system.lock` | lock the screen (mac: sleeps the display) |

## Status
Phone: `{"type":"statusRequest"}` · Agent:
`{"type":"status","status":{"hostName":"Studio","platform":"macos","volume":40,"muted":false}}`.
`volume` and `muted` may be absent when the agent can't read them.

## Compatibility rules
- Add new actions and fields; never rename or remove one. Unknown fields must be ignored.
- A breaking change bumps `RemoteProtocol.version`.
