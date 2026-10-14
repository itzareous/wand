# Contributing to Wand

Thanks for helping! Small, focused pull requests are the easiest to review and merge.

## Getting set up

Follow **Build it yourself** in the [README](README.md). In short: Xcode, `brew install xcodegen`, copy
`Config/Local.xcconfig.example` to `Config/Local.xcconfig` with your own team, then `xcodegen generate`.

- Never commit `Wand.xcodeproj` (it's generated) or `Config/Local.xcconfig` (it's yours).
- Edit `project.yml` for project and Info.plist changes, never the generated project.

## Easiest first contribution: shortcuts for an app

Every app's shortcut set lives in one file:
[`apps/mac-agent/Sources/ShortcutCatalog.swift`](apps/mac-agent/Sources/ShortcutCatalog.swift).

1. **Find the app's bundle id:**
   ```sh
   osascript -e 'id of app "Linear"'
   ```
2. **Add a set** to `sets`, following the existing ones:
   ```swift
   ShortcutSet(name: "Linear", bundleIds: ["com.linear"], shortcuts: [
       s("linear.search", "Search", "magnifyingglass", kVK_ANSI_K, cmd),
       s("linear.newIssue", "New issue", "plus", kVK_ANSI_C, []),
   ]),
   ```
   - `id`: `<set>.<action>`. **Ids are a contract**: phones send them back, so never rename an existing one.
   - `title`: short, because it shows on a small button.
   - `symbol`: an [SF Symbol](https://developer.apple.com/sf-symbols/) name.
   - Key: a `kVK_…` constant from Carbon; modifiers are `cmd`, `shift`, `ctrl` and `opt`.
3. **Only use the app's default shortcuts.** If you're not sure a combo is the stock default, leave it out. A button that
   does the wrong thing is worse than no button.
4. **Test it** with the app in front:
   ```sh
   cd tools/remote-cli
   swift run remote-cli context               # should list your set
   swift run remote-cli shortcut linear.search
   ```
   Debug builds also assert that ids are unique and namespaced when the Mac app starts.

Aim for 4–10 shortcuts per app, the ones you'd actually reach for from across the room.

## Changing the protocol

The phone and the computer talk JSON over a WebSocket. See [docs/protocol.md](docs/protocol.md).

- Change `packages/RemoteKit/Sources/RemoteKit/RemoteProtocol.swift`, `docs/protocol.md` and the tests in the **same** PR.
- **Only add** messages and fields; never rename or remove one. Unknown fields must be ignored.
- Run `cd packages/RemoteKit && swift test`.

## Code style

- Match the surrounding code. SwiftUI, Swift 5 language mode, UI state on `@MainActor`.
- UI: dark look, capsule (fully rounded) buttons, no shadows.
- User-facing text says **Wand**. Don't use Apple trademarks such as "Touch Bar" in the app or on the site.

## Pull requests

- Describe what changed and how you tested it. For UI changes, include a screenshot or screen recording from a real
  iPhone or Mac.
- CI builds both apps and runs the protocol tests on every pull request, and it must pass.

## Reporting bugs

Open an issue with your macOS and iOS versions, what you did, what you expected and what happened. If the Mac app
can't press keys, check System Settings → Privacy & Security → Accessibility first.
