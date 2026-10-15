import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A panel that can take keyboard focus without activating Wand, so the app you were in stays
/// active and receives the paste.
private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// The drop-down clipboard history (double-tap right ⌥).
@MainActor
final class ClipboardPanel {
    private let history: ClipboardHistory
    private let panel: KeyPanel
    private var resignObserver: NSObjectProtocol?

    init(history: ClipboardHistory) {
        self.history = history
        panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
                         styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        resignObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        let view = ClipboardListView(history: history, onPick: { [weak self] in self?.paste($0) }, onClose: { [weak self] in self?.hide() })
        panel.contentView = NSHostingView(rootView: view)
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let size = panel.frame.size
            let finalOrigin = NSPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 8)
            panel.setFrameOrigin(NSPoint(x: finalOrigin.x, y: finalOrigin.y + 24))
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrameOrigin(finalOrigin)
                panel.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
    }

    /// Copy the item, close, then ⌘V into the app that was in front.
    private func paste(_ item: ClipItem) {
        history.copyToPasteboard(item)
        hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            try? SystemControl.post(KeyCombo(key: CGKeyCode(kVK_ANSI_V), flags: .maskCommand))
        }
    }
}

private struct ClipboardListView: View {
    let history: ClipboardHistory
    let onPick: (ClipItem) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var selection = 0
    @FocusState private var searchFocused: Bool

    private var results: [ClipItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return history.items }
        return history.items.filter { $0.text.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search your clipboard", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($searchFocused)
                Text("↩ paste  esc close").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 18)
            .frame(height: 52)

            Divider()

            if results.isEmpty {
                VStack(spacing: 10) {
                    Image("Mascot").resizable().scaledToFit().frame(width: 44)
                    Text(history.items.isEmpty ? "Copy something and it shows up here." : "No matches")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(results.prefix(60).enumerated()), id: \.element.id) { index, item in
                                ClipRow(item: item, index: index, selected: index == selection)
                                    .id(index)
                                    .onTapGesture { onPick(item) }
                                    .onHover { if $0 { selection = index } }
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: selection) { _, value in proxy.scrollTo(value) }
                }
            }
        }
        .frame(width: 560, height: 420)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.primary.opacity(0.1)))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear { searchFocused = true; selection = 0 }
        .onChange(of: query) { _, _ in selection = 0 }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.return) { pick(selection); return .handled }
        .onKeyPress(.escape) { onClose(); return .handled }
        .onKeyPress(characters: .decimalDigits, phases: .down) { press in
            guard press.modifiers.contains(.command), let digit = Int(press.characters), digit >= 1 else { return .ignored }
            pick(digit - 1)
            return .handled
        }
    }

    private func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selection = min(max(0, selection + delta), min(results.count, 60) - 1)
    }

    private func pick(_ index: Int) {
        guard results.indices.contains(index) else { return }
        onPick(results[index])
    }
}

private struct ClipRow: View {
    let item: ClipItem
    let index: Int
    let selected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 13.5))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 3) {
                Text(item.date, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    if let app = item.appName {
                        Text(app).font(.system(size: 11)).foregroundStyle(.tertiary).lineLimit(1)
                    }
                    if index < 9 {
                        Text("⌘\(index + 1)").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? Color.wandBlue.opacity(0.14) : .clear))
    }
}
