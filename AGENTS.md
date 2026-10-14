# Agent instructions: touchbar-remote

A phone remote for your computer, styled like the MacBook Touch Bar: play/pause, volume, lock and quick actions.
Read `docs/architecture.md`, `docs/protocol.md` and `docs/roadmap.md` before changing anything.

## Setup (build Mac, needs full Xcode)
```sh
brew install xcodegen
xcodegen generate          # creates Remote.xcodeproj (gitignored, never commit it)
open Remote.xcodeproj      # schemes: RemoteiOS, RemoteMacAgent
cd packages/RemoteKit && swift test
```

Test an agent without a phone: `cd tools/remote-cli && swift run remote-cli pair <code>`, then
`swift run remote-cli status` or `swift run remote-cli volume.up`. The token is kept in `~/.touchbar-remote-cli-token`.

Debug-only test hooks:
- **Agent**: debug builds print `Pairing code: NNNNNN` to stderr. Run the binary directly to see it:
  `<DerivedData>/Build/Products/Debug/RemoteMacAgent.app/Contents/MacOS/RemoteMacAgent`.
- **iOS app**: the launch arguments `-autoOpen YES -pairingCode NNNNNN` open the first agent found and pair it with no taps
  (`xcrun simctl launch <sim> com.qorelly.remote.ios -autoOpen YES -pairingCode NNNNNN`).
- **XcodeGen**: if it is installed from the release zip, run the real binary and not a symlink, or the settings presets
  are not found (this shows up as `Module name "" is not a valid identifier`).
Build the Mac agent signed with a real certificate, never ad-hoc, or the Accessibility grant is lost on every rebuild
(see docs/architecture.md). Run it from `/Applications/RemoteMacAgent.app`.
Set `DEVELOPMENT_TEAM` in `project.yml` for device builds. Edit `project.yml` for any project or Info.plist
change. Never edit the generated project or Info.plists by hand.

## Rules
- Work one roadmap slice at a time, with explicit scope. Don't touch unrelated surfaces.
- Audit before implementing. Read the relevant files and report your plan first.
- Any protocol change updates `RemoteProtocol.swift`, `docs/protocol.md` and the tests in the same change.
  Only add to the protocol; never rename an action string.
- If the code contradicts the docs, stop and report it. Don't build past it.
- "It works" claims need proof: a screenshot or screen recording from a real iPhone and Mac.
- UI: capsule (rounded-full) buttons, no shadows. Dark Touch Bar look.
- Swift 5 language mode for now. Keep UI state on `@MainActor`.
