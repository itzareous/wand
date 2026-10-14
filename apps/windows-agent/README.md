# Windows agent (not started)

Tray app that does on Windows what `apps/mac-agent` does on macOS.

- Must implement `docs/protocol.md` exactly. The JSON strings are the contract, not the Swift types.
- Advertise `_wand._tcp` over mDNS so the iPhone app finds it with no extra work.
- Suggested stack: .NET 8 (C#) WinForms/WPF tray app. Media and volume keys via `SendInput` with
  `VK_MEDIA_PLAY_PAUSE` (0xB3), `VK_MEDIA_NEXT_TRACK` (0xB0), `VK_MEDIA_PREV_TRACK` (0xB1),
  `VK_VOLUME_UP` (0xAF), `VK_VOLUME_DOWN` (0xAE), `VK_VOLUME_MUTE` (0xAD); volume level via
  CoreAudio `IAudioEndpointVolume`; lock via `LockWorkStation()`.
- Built on a Windows machine, after the macOS agent and the iPhone app work end to end.
