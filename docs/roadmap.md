# Roadmap: one verifiable slice at a time

## Slice 0: Foundation (this commit)
- [x] RemoteKit protocol + tests (`swift test` passes)
- [x] Mac agent: Bonjour + WebSocket server, pairing code, media keys, volume, lock
- [x] iPhone app: discovery, pairing, Touch Bar–style controls, haptics
- [ ] **First run on the build Mac**: `xcodegen generate`, build both targets, pair a real iPhone,
      verify every button works. Screenshots/screen recording as proof. Fix compile issues found.
      (The foundation was typechecked against the macOS SDK only, without Xcode; the iOS target has never been compiled.)

## Next slices (in order)
1. **Keychain**: move tokens from UserDefaults to Keychain on both sides. Add a "Forget this computer" option on the phone.
2. **Launch at login**: `SMAppService.mainApp` toggle in the agent menu.
3. **Now playing**: show the track title and artist on the phone (agent reads it; investigate the public options before any private API).
4. **Screen peek**: ScreenCaptureKit snapshot (`SCScreenshotManager`) about every 1s as JPEG over the socket. Add a `screen.peek` request to the protocol.
5. **Control Center and Lock Screen controls**: `ControlWidget` buttons for play/pause and volume (App Intents) and a Home Screen widget.
   They need to reach the agent without opening the app, so investigate the App Group plus a background connection.
6. **Remote access off Wi-Fi**: decide between a Tailscale-style approach and a relay server. Add TLS.
7. **Custom quick actions**: user-defined shortcuts (open app, run a Shortcut, keystroke).
8. **Windows agent**: see `apps/windows-agent/README.md`.
9. **Ship**: App Store listing for iPhone, a notarized DMG for the Mac agent, and the product name (drop "Touch Bar", which is Apple's trademark).
