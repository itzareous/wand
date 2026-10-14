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

## App context and shortcuts
Whenever the app in front on the computer changes, and once right after `welcome`, the agent pushes:
`{"type":"context","context":{"bundleId":"com.apple.finder","appName":"Finder","icon":"<base64 PNG>","setName":"Finder","shortcuts":[{"id":"finder.back","title":"Back","symbol":"chevron.left"}, …]}}`

- `symbol` is an SF Symbol name. `icon` is a small PNG (96 px), and may be absent.
- The agent owns what each shortcut does. The phone only sends the id back:
  `{"type":"runShortcut","id":"<uuid>","shortcutId":"finder.back"}` → `ack`.
- The agent checks the id against the shortcut set of the app in front **now**. If the user switched apps in between,
  it replies `ok:false` instead of pressing keys in the wrong app.
- Shortcut ids are `<set>.<action>`, and they are a contract: never rename one.

## Keyboard and app switcher
- `{"type":"typeText","id":"…","text":"hello"}` types text, any characters including emoji. `\n` presses Return.
- `{"type":"pressKey","id":"…","key":"left"}`, where `key` is one of `up down left right return escape tab delete space`.
- `{"type":"appSwitcher","id":"…","switcher":"open"}`, where `switcher` is one of `open next previous choose cancel`.
  - `open` holds ⌘ and shows the ⌘Tab switcher.
  - While it is open, `pressKey` left/right/tab move the selection, `return` chooses and `escape` cancels.
  - The agent **always releases ⌘**: on choose/cancel, when the phone disconnects, and after 15 s idle.
  - `status.switcherActive` reports whether the switcher is open (pushed on every change).

## Status
Phone: `{"type":"statusRequest"}` · Agent:
`{"type":"status","status":{"hostName":"Studio","platform":"macos","volume":40,"muted":false}}`.
`volume` and `muted` may be absent when the agent can't read them.

## Compatibility rules
- Add new actions and fields; never rename or remove one. Unknown fields must be ignored.
- A breaking change bumps `RemoteProtocol.version`.
