# Architecture

```
iPhone app (SwiftUI)  ──Bonjour discovery──▶  Desktop agent (menu bar / tray)
        │                                            │
        └────── WebSocket, JSON (docs/protocol.md) ──┘
                                                     ▼
                                     OS calls: media keys, volume, lock, (later) screen capture
```

| Path | What | Builds on |
|---|---|---|
| `packages/RemoteKit` | Shared Swift package: message types, action list, Bonjour type | any Mac (`swift build`, `swift test`) |
| `apps/ios` | iPhone app: discovers agents, pairs, Touch Bar–style controls | Mac with Xcode |
| `apps/mac-agent` | macOS menu-bar agent: WebSocket server, executes actions | Mac with Xcode |
| `apps/windows-agent` | Windows tray agent (not started) | Windows |
| `tools/remote-cli` | Dev CLI client implementing the phone side of the protocol | any Mac (`swift run`) |
| `project.yml` | XcodeGen spec producing one `Wand.xcodeproj` with both Apple targets | `xcodegen generate` |

## Key decisions
- **Native Swift, not a PWA.** It unlocks Lock Screen and Control Center controls, widgets, Live Activities,
  haptics and Bonjour discovery.
- **The agent is a server and the phone is a client.** The computer is plugged in and always on. The phone comes and goes.
- **The JSON protocol is the contract.** That keeps the Windows agent (non-Swift) a peer, not an afterthought.
- **The Mac agent is not sandboxed** and ships outside the Mac App Store. Synthesised media keys need
  Accessibility, and screen peek needs Screen Recording. The iPhone app goes on the App Store.
- **Pairing**: a single-use 6-digit code shown on the computer is exchanged for a long random token stored on the phone.

## macOS permissions the agent needs
- **Accessibility**: play/pause, next and previous (synthesised media keys). The menu has a button that triggers the prompt.
- **None for volume**: AppleScript `set volume`.
- **Screen Recording**: later, for screen peek.
- **Local Network**: prompted automatically.

On macOS 27 the Accessibility list is titled **Privacy & Security → Device Control and Data Access**.

**Signing matters for this grant.** Sign the agent with a real certificate (Apple Development locally, Developer ID for release):
- With an ad-hoc signature (`CODE_SIGN_IDENTITY=-`), the grant is pinned to that exact build, so every rebuild silently loses it.
- With a certificate, macOS stores a requirement based on the certificate, and the grant survives rebuilds.

If play/pause returns the "allow Accessibility" error even though the switch is on, remove the entry (−), add
`/Applications/Wand.app` again (+), and then **restart the agent**. A grant only takes effect for a newly launched process.
