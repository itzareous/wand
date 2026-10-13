# touchbar-remote (working name)

Your phone as a Touch Bar for your Mac or PC. Pause music, change the volume, lock the screen,
peek at your screen, and run quick actions from across the room.

```
apps/ios             iPhone app (SwiftUI)
apps/mac-agent       macOS menu-bar agent (SwiftUI + Network.framework)
apps/windows-agent   Windows tray agent (planned)
packages/RemoteKit   shared protocol (Swift package)
docs/                architecture, wire protocol, roadmap
project.yml          XcodeGen spec for both Apple apps
```

## Quick start (Mac with Xcode)
```sh
brew install xcodegen && xcodegen generate && open Remote.xcodeproj
```
1. Run **RemoteMacAgent**. A remote icon appears in the menu bar with a 6-digit pairing code.
   Click "Allow media keys" and enable it in Accessibility.
2. Run **RemoteiOS** on an iPhone on the same Wi-Fi, tap your Mac and enter the code.

See `docs/roadmap.md` for status and what's next.
