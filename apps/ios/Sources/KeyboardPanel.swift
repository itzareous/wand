import RemoteKit
import SwiftUI

/// Type on the computer, press arrows and special keys, and pick apps with the ⌘Tab switcher.
struct KeyboardPanel: View {
    let client: RemoteClient
    let onTap: () -> Void

    /// What the text field shows. Edits are diffed and sent as typing/deletes as they happen.
    @State private var buffer = ""
    /// Set when we change `buffer` ourselves, so the change isn't sent to the computer.
    @State private var ignoreNextChange = false
    @FocusState private var isTyping: Bool

    private var switcherActive: Bool { client.status?.switcherActive == true }

    var body: some View {
        VStack(spacing: 16) {
            typingField
            switcherStrip
            arrowPad
        }
    }

    // MARK: Typing

    private var typingField: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard")
                .foregroundStyle(.secondary)
            TextField("Type on your computer", text: $buffer)
                .focused($isTyping)
                .autocorrectionDisabled()
                .submitLabel(.return)
                .onSubmit {
                    client.press(.return)
                    clearBuffer()
                    isTyping = true
                }
            if !buffer.isEmpty {
                Button { clearBuffer() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear field (keeps the text on the computer)")
            }
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 52)
        .background(Capsule().fill(Color(white: 0.08)))
        .onChange(of: buffer) { old, new in
            if ignoreNextChange { ignoreNextChange = false; return }
            sendDiff(from: old, to: new)
        }
    }

    private func clearBuffer() {
        guard !buffer.isEmpty else { return }
        ignoreNextChange = true
        buffer = ""
    }

    /// Mirrors a text-field edit on the computer: delete what changed, type what's new.
    private func sendDiff(from old: String, to new: String) {
        let common = old.commonPrefix(with: new)
        for _ in 0..<(old.count - common.count) { client.press(.delete) }
        let added = String(new.dropFirst(common.count))
        if !added.isEmpty { client.type(added) }
    }

    // MARK: App switcher

    @ViewBuilder private var switcherStrip: some View {
        if switcherActive {
            HStack(spacing: 10) {
                pill("Cancel", "xmark") { client.switcher(.cancel) }
                pill("Open app", "checkmark", prominent: true) { client.switcher(.choose) }
            }
            .padding(8)
            .background(Capsule().fill(Color(white: 0.08)))
            Text("Use ← → to pick an app")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            pill("Switch apps", "square.on.square") { client.switcher(.open) }
                .padding(8)
                .background(Capsule().fill(Color(white: 0.08)))
        }
    }

    // MARK: Arrow pad

    private var arrowPad: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                key("Esc", "escape", .escape)
                key(nil, "arrow.up", .up)
                key(nil, "delete.left", .delete)
            }
            HStack(spacing: 10) {
                key(nil, "arrow.left", .left)
                key(nil, "arrow.down", .down)
                key(nil, "arrow.right", .right)
            }
            HStack(spacing: 10) {
                key("Tab", "arrow.right.to.line", .tab)
                key("Space", "space", .space)
                key("Return", "return", .return, prominent: true)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(Color(white: 0.08)))
    }

    private func key(_ title: String?, _ symbol: String, _ key: SpecialKey, prominent: Bool = false) -> some View {
        Button {
            onTap()
            client.press(key)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.title3)
                if let title { Text(title).font(.caption2) }
            }
            .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(PadKeyStyle(prominent: prominent))
        .accessibilityLabel(title ?? key.rawValue)
    }

    private func pill(_ title: String, _ symbol: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            onTap()
            action()
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(PadKeyStyle(prominent: prominent))
    }
}

private struct PadKeyStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? .black : .white)
            .background(Capsule().fill(prominent ? Color.white : Color.white.opacity(configuration.isPressed ? 0.3 : 0.12)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
