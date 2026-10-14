# Roadmap: one verifiable slice at a time

## Slice 0: Foundation (this commit)
- [x] RemoteKit protocol + tests (`swift test` passes)
- [x] Mac agent: Bonjour + WebSocket server, pairing code, media keys, volume, lock
- [x] iPhone app: discovery, pairing, Touch Bar–style controls, haptics
- [x] Both targets build with Xcode 27 (no source changes needed for compilation)
- [x] Agent verified end to end with `tools/remote-cli` (2026-10-14): pairing, single-use code, reused code rejected,
      status, volume up and down, mute on and off, play/pause correctly refused without Accessibility
- [x] Fixed: `rejected` was dropped because the agent closed the socket before flushing it. The iOS client now
      shows a failure on disconnect instead of hanging on "Connecting…"
- [x] iOS app in Simulator against the live agent (2026-10-14, `docs/screenshots/01-04`): discovery, pairing screen,
      paired controls showing live Mac volume, relaunch reconnects with the stored token (no code needed)
- [ ] Landscape single-strip layout (needs a person to rotate the Simulator or a phone)
- [x] Verified by a person on the Mac (2026-10-14): play/pause, volume, mute and lock all work from the Simulator app
- [x] Fixed: the media-key permission check now uses `CGPreflightPostEventAccess` (the "post events" grant), and the agent
      asks for it on first launch
- [ ] Next and previous track confirmed by a person
- [ ] Real iPhone on the same Wi-Fi (needs a signing team in `project.yml`)

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
