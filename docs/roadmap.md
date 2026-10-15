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

## Slice 1: App shortcuts (branch `slice-1-app-shortcuts`)
- [x] Protocol: `context` push and `runShortcut` (additive, with tests)
- [x] Agent: detects the frontmost app, keeps per-app shortcut sets (`ShortcutCatalog.swift`) and presses keys
- [x] Sets: Browser (Chrome, Safari, Arc, Dia, Firefox, Brave, Edge, Opera, Vivaldi), Figma, Code editor (VS Code,
      Cursor, Windsurf, Zed), Xcode, Terminal (Terminal, iTerm, Ghostty, Warp), Slack, Zoom, Teams, Finder, Mail,
      Notion, Notes, Keynote, PowerPoint, Spotify, and General for everything else
- [x] iPhone: app card with icon and shortcut grid (portrait), scrolling strip (landscape), updates live on app switch
- [x] Verified (2026-10-14): Terminal → Finder switch updates the phone live (screenshots 05, 06); Finder "Downloads"
      really opens Downloads; a stale shortcut from another app is refused
- [ ] A person tries the browser and Figma sets in the real apps

## Slice 2: Keyboard and app switcher (branch `slice-2-keyboard`)
- [x] Protocol: `typeText`, `pressKey`, `appSwitcher`, `status.switcherActive` (additive, tested)
- [x] Agent: unicode typing, special keys, ⌘Tab switcher with guaranteed ⌘ release
- [x] iPhone: Keyboard tab with a live-typing field (edits are mirrored as typing and deletes), switcher and arrow pad
- [x] Verified (2026-10-14) on the Mac: typed `Hello from the phone ✓ é`, Return and Delete into TextEdit;
      switcher open→cancel stays put, open→next→choose switches app, disconnect mid-switch releases ⌘
- [ ] A person tries it from a real iPhone

## Slice 3: Rename to Wand (branch `slice-3-wand`)
- [x] Apps, bundle ids (`com.qorelly.wand`, `com.qorelly.wand.mac`), schemes, Bonjour `_wand._tcp`, docs

## Slice 4: Mac app (branch `slice-4-mac-app`)
- [x] Main window that opens on launch (and on reopen from Finder/Spotlight or the menu bar); stays hidden when opened at login
- [x] First-run setup: welcome → Accessibility (live ✓, no relaunch) → pair (code + QR, moves on by itself) → done
      (with Open at Login)
- [x] Home: connection status, paired iPhones with per-device Forget (disconnects at once), permissions, Open at Login
- [x] Pairing QR `wand://pair?name=…&code=…`; the iPhone handles the `wand` scheme and pairs without typing
- [x] Seen working by a person on the Mac (2026-10-14)
- [ ] QR pairing confirmed from a real iPhone camera
- [ ] App icon for both apps

## Dictation (branch `dictation`)
- [x] Hold Right ⌥ Option anywhere → record → transcribe → typed into the app in front; works with or without a paired phone
- [x] Engines: Cloud (OpenAI, Groq, or any OpenAI-compatible URL; key stored in the Keychain) or On this Mac (Apple Speech)
- [x] On-screen pill: listening level meter, transcribing, errors. Pressing another key while holding ⌥ cancels.
- [x] Cloud request verified against a local mock of `/audio/transcriptions` (upload shape, errors, missing key)
- [ ] A person dictates for real with each engine
- [x] Dictate from the phone: hold-to-talk records on the iPhone, the Mac transcribes with its engine and types
      (protocol `dictate`, `status.dictationReady`). Verified end to end with the on-device engine into TextEdit.
- [ ] A person tries hold-to-talk on a real iPhone
- Next: optional LLM cleanup of the transcript, voice commands

## Clipboard history (branch `clipboard-history`)
- [x] Right ⌥ is shared: hold to dictate (starts after 180 ms, so taps don't flash the pill), double-tap for clipboard
- [x] Text clipboard history saved in ~/Library/Application Support/Wand (100 items, data protection), skipping
      concealed and transient pasteboard types
- [x] Drop-down panel: search, ↑/↓, Return pastes into the app in front (the panel never activates Wand), Esc, ⌘1–9
- [x] The panel opens at the text cursor (Accessibility caret bounds), above it near the screen bottom, and falls back
      to the mouse pointer when an app doesn't expose its caret. Verified the caret is found in TextEdit.
- [x] Dashboard Clipboard page (on/off, list, copy, remove, clear) and a Home card; off by default for new users
- [x] Verified (2026-10-15): copies captured with the source app; a concealed item was not stored
- [ ] A person double-taps right ⌥ and pastes from the drop-down
- Later: images and files, and clipboard history on the iPhone

## Next slices (in order)
- **Screenshot** (next): full screen or front app → Mac clipboard + phone (share sheet). Needs Screen Recording.
- **Trackpad**: move, click and scroll from the phone (the keyboard part is done in slice 2).
- **Now Playing**: Music and Spotify first; browser video only after research.
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
