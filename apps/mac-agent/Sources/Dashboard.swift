import AppKit
import AVFoundation
import RemoteKit
import SwiftUI

/// The main window after setup: a sidebar with Home, iPhone, Dictation, Shortcuts and Settings.
struct DashboardView: View {
    let agent: Agent
    /// Snapshot rendering can't draw a ScrollView, so it lays pages out flat.
    var scrolls = true
    @State private var page: Page

    enum Page: String, CaseIterable, Identifiable {
        case home, iPhone, dictation, clipboard, shortcuts, settings
        var id: Self { self }
        var title: String {
            switch self {
            case .home: "Home"
            case .iPhone: "iPhone"
            case .dictation: "Dictation"
            case .clipboard: "Clipboard"
            case .shortcuts: "Shortcuts"
            case .settings: "Settings"
            }
        }
        var symbol: String {
            switch self {
            case .home: "house"
            case .iPhone: "iphone"
            case .dictation: "mic"
            case .clipboard: "doc.on.clipboard"
            case .shortcuts: "square.grid.2x2"
            case .settings: "gearshape"
            }
        }
        var selectedSymbol: String {
            switch self {
            case .home: "house.fill"
            case .iPhone: "iphone" // there is no filled iPhone symbol
            case .dictation: "mic.fill"
            case .clipboard: "doc.on.clipboard.fill"
            case .shortcuts: "square.grid.2x2.fill"
            case .settings: "gearshape.fill"
            }
        }
    }

    init(agent: Agent, page: Page = .home, scrolls: Bool = true) {
        self.agent = agent
        self.scrolls = scrolls
        _page = State(initialValue: page)
    }

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(page: $page)
            Divider()
            Group {
                if scrolls {
                    ScrollView { content }
                } else {
                    content.frame(maxHeight: .infinity, alignment: .top)
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in agent.refreshAccessibility() }
    }

    private var content: some View {
        Group {
            switch page {
            case .home: HomePage(agent: agent, go: { page = $0 })
            case .iPhone: IPhonePage(agent: agent)
            case .dictation: DictationPage(dictation: agent.dictation)
            case .clipboard: ClipboardPage(history: agent.clipboard, openPanel: { agent.clipboardPanel.show() })
            case .shortcuts: ShortcutsPage(currentBundleId: agent.frontmostApp.context.bundleId)
            case .settings: SettingsPage(agent: agent)
            }
        }
        .frame(maxWidth: 680, alignment: .leading)
        .padding(.horizontal, 40)
        .padding(.top, 44)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @Binding var page: DashboardView.Page

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                WandMark(size: 30)
                Text("Wand").font(.system(size: 17, weight: .bold)).tracking(-0.3)
            }
            .padding(.horizontal, 10)
            .padding(.top, 36)
            .padding(.bottom, 22)

            ForEach(DashboardView.Page.allCases) { item in
                Button { page = item } label: {
                    HStack(spacing: 10) {
                        Image(systemName: page == item ? item.selectedSymbol : item.symbol)
                            .frame(width: 18)
                        Text(item.title)
                        Spacer()
                    }
                    .font(.system(size: 13.5, weight: page == item ? .semibold : .regular))
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .contentShape(Capsule())
                    .background(Capsule().fill(page == item ? Color.primary.opacity(0.07) : .clear))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button { NSWorkspace.shared.open(URL(string: "https://github.com/itzareous/wand")!) } label: {
                Label("Open source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 12)
        .frame(width: 210)
        .background(Color.primary.opacity(0.025))
    }
}

// MARK: - Shared pieces

private struct PageTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 28, weight: .bold)).tracking(-0.6)
            if let subtitle {
                Text(subtitle).font(.system(size: 14)).foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 24)
    }
}

private struct Card<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.primary.opacity(0.04)))
    }
}

private struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            .padding(.top, 28).padding(.bottom, 10)
    }
}

private struct PillButton: View {
    let title: String
    var prominent = false
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1).fixedSize()
                .padding(.horizontal, 14).frame(height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(prominent ? Color.white : (role == .destructive ? Color.red : Color.primary))
        .background(Capsule().fill(prominent ? Color.primary : Color.primary.opacity(0.07)))
    }
}

private struct Dot: View {
    let on: Bool
    var body: some View {
        Circle().fill(on ? Color.green : Color.secondary.opacity(0.5)).frame(width: 8, height: 8)
    }
}

private struct Row<Trailing: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .medium))
                if let detail {
                    Text(detail).font(.system(size: 12.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Home

private struct HomePage: View {
    let agent: Agent
    let go: (DashboardView.Page) -> Void
    private var dictation: DictationController { agent.dictation }
    private var stats: DictationStats { agent.dictation.stats }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageTitle(title: greeting, subtitle: "Here's what Wand is up to on this Mac.")

            HStack(spacing: 12) {
                StatTile(value: stats.totalWords.formatted(), label: "Words dictated")
                StatTile(value: stats.todayWords.formatted(), label: "Words today")
                StatTile(value: "\(stats.minutesSaved) min", label: "Time saved vs typing")
            }

            HStack(alignment: .top, spacing: 12) {
                Card {
                    HStack {
                        Image(systemName: "iphone").font(.title3)
                        Spacer()
                        Dot(on: !agent.connectedTokens.isEmpty)
                    }
                    Text("iPhone").font(.system(size: 16, weight: .semibold)).padding(.top, 14)
                    Text(iPhoneStatus).font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 2)
                        .fixedSize(horizontal: false, vertical: true)
                    PillButton(title: agent.pairedDevices.isEmpty ? "Pair your iPhone" : "Manage") { go(.iPhone) }
                        .padding(.top, 16)
                }
                Card {
                    HStack {
                        Image(systemName: "mic").font(.title3)
                        Spacer()
                        Dot(on: dictation.isEnabled)
                    }
                    Text("Dictation").font(.system(size: 16, weight: .semibold)).padding(.top, 14)
                    Text(dictation.isEnabled ? "Hold right ⌥ to talk" : "Off")
                        .font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 2)
                        .fixedSize(horizontal: false, vertical: true)
                    PillButton(title: dictation.isEnabled ? "Settings" : "Turn on") {
                        if !dictation.isEnabled { dictation.isEnabled = true }
                        go(.dictation)
                    }
                    .padding(.top, 16)
                }
                Card {
                    HStack {
                        Image(systemName: "doc.on.clipboard").font(.title3).frame(height: 22)
                        Spacer()
                        Dot(on: agent.clipboard.isEnabled)
                    }
                    Text("Clipboard").font(.system(size: 16, weight: .semibold)).padding(.top, 14)
                    Text(agent.clipboard.isEnabled ? "Double-tap right ⌥" : "Off")
                        .font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 2)
                        .fixedSize(horizontal: false, vertical: true)
                    PillButton(title: agent.clipboard.isEnabled ? "Open" : "Turn on") {
                        if !agent.clipboard.isEnabled { agent.clipboard.isEnabled = true }
                        go(.clipboard)
                    }
                    .padding(.top, 16)
                }
            }
            .padding(.top, 12)

            if !agent.hasAccessibility {
                Card {
                    HStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wand can't press keys yet").font(.system(size: 14, weight: .semibold))
                            Text("Allow Wand in Privacy & Security → Accessibility.").font(.system(size: 12.5)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        PillButton(title: "Fix", prominent: true) {
                            SystemControl.requestAccessibility()
                            SystemControl.openAccessibilitySettings()
                        }
                    }
                }
                .padding(.top, 12)
            }

            SectionLabel(text: "Try this")
            Card(padding: 0) {
                TipRow(symbol: "mic.fill", title: "Dictate anywhere", detail: "Hold the right ⌥ option key in any text field, speak, and let go.")
                Divider().padding(.leading, 56)
                TipRow(symbol: "hand.tap.fill", title: "Hold to talk on your iPhone", detail: "Open Wand on your phone and use the mic button. Your Mac types it.")
                Divider().padding(.leading, 56)
                TipRow(symbol: "square.grid.2x2.fill", title: "Shortcuts follow your app", detail: "Switch to Chrome, Figma or Keynote and your phone shows its shortcuts.")
            }
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    private var iPhoneStatus: String {
        if !agent.connectedTokens.isEmpty { return "Connected" }
        if agent.pairedDevices.isEmpty { return "Not paired yet" }
        return "Not connected"
    }
}

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 26, weight: .bold)).tracking(-0.6).contentTransition(.numericText())
            Text(label).font(.system(size: 12.5)).foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.wandBlue.opacity(0.07)))
    }
}

private struct TipRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).foregroundStyle(Color.wandBlue).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .medium))
                Text(detail).font(.system(size: 12.5)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: - iPhone

private struct IPhonePage: View {
    let agent: Agent
    @State private var showPairing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageTitle(title: "iPhone", subtitle: "Control this Mac from your phone on the same Wi-Fi.")

            Card {
                HStack(spacing: 12) {
                    Dot(on: !agent.connectedTokens.isEmpty)
                    Text(statusText).font(.system(size: 14, weight: .medium))
                    Spacer()
                    Text(agent.serviceName).font(.system(size: 12.5)).foregroundStyle(.secondary)
                }
            }

            SectionLabel(text: "Paired iPhones")
            Card(padding: 0) {
                if agent.pairedDevices.isEmpty {
                    Text("No iPhone paired yet.").foregroundStyle(.secondary).padding(20)
                }
                ForEach(Array(agent.pairedDevices.enumerated()), id: \.element.id) { index, device in
                    if index > 0 { Divider().padding(.leading, 56) }
                    HStack(spacing: 14) {
                        Image(systemName: "iphone").font(.title3).frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name).font(.system(size: 14, weight: .medium))
                            Text(agent.connectedTokens.contains(device.id) ? "Connected" : "Not connected")
                                .font(.system(size: 12)).foregroundStyle(agent.connectedTokens.contains(device.id) ? .green : .secondary)
                        }
                        Spacer()
                        PillButton(title: "Forget", role: .destructive) { agent.forget(device) }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }
            }

            SectionLabel(text: "Pair a new iPhone")
            Card {
                if showPairing {
                    PairingCard(agent: agent)
                } else {
                    HStack {
                        Text("Show a QR code to scan with your iPhone camera.").font(.system(size: 13)).foregroundStyle(.secondary)
                        Spacer()
                        PillButton(title: "Show code", prominent: true) { showPairing = true }
                    }
                }
            }
        }
        .onChange(of: agent.pairedDevices.count) { _, _ in showPairing = false }
    }

    private var statusText: String {
        switch agent.connectedTokens.count {
        case 0: agent.isListening ? "Waiting for your iPhone" : "Starting…"
        case 1: "iPhone connected"
        default: "\(agent.connectedTokens.count) iPhones connected"
        }
    }
}

// MARK: - Dictation

private struct DictationPage: View {
    @Bindable var dictation: DictationController
    @State private var apiKey = ""
    @State private var micStatus = AVCaptureDevice.authorizationStatus(for: .audio)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageTitle(title: "Dictation", subtitle: "Speak instead of typing, in any app.")

            Card {
                Toggle(isOn: $dictation.isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dictation").font(.system(size: 14, weight: .medium))
                        Text("Hold the right ⌥ option key, speak, and let go.").font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }

            SectionLabel(text: "Transcription")
            HStack(spacing: 12) {
                EngineCard(engine: .cloud, selected: $dictation.engine, title: "Cloud", detail: "Most accurate. Uses your own API key.", symbol: "cloud")
                EngineCard(engine: .onDevice, selected: $dictation.engine, title: "On this Mac", detail: "Private and free. Audio never leaves your Mac.", symbol: "lock.laptopcomputer")
            }

            if dictation.engine == .cloud {
                Card(padding: 0) {
                    Group {
                        Row(title: "Provider") {
                            Picker("", selection: $dictation.provider) {
                                ForEach(CloudProvider.allCases) { Text($0.title).tag($0) }
                            }
                            .labelsHidden().fixedSize()
                        }
                        Divider()
                        if dictation.provider == .custom {
                            Row(title: "API URL") {
                                TextField("", text: $dictation.baseURL, prompt: Text("https://your-server/v1"))
                                    .textFieldStyle(.roundedBorder).frame(width: 260)
                            }
                            Divider()
                        }
                        Row(title: "Model") {
                            TextField("", text: $dictation.model).textFieldStyle(.roundedBorder).frame(width: 260)
                        }
                        Divider()
                        Row(title: "API key", detail: "Stored in your Mac's Keychain") {
                            SecureField("", text: $apiKey, prompt: Text("Paste your key")).textFieldStyle(.roundedBorder).frame(width: 260)
                                .onChange(of: apiKey) { _, value in dictation.apiKey = value }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 12)
            }

            SectionLabel(text: "Microphone")
            Card {
                HStack {
                    Label(micStatus == .authorized ? "Microphone allowed" : "Microphone not allowed",
                          systemImage: micStatus == .authorized ? "checkmark.circle.fill" : "mic.slash")
                        .foregroundStyle(micStatus == .authorized ? .green : .secondary)
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    if micStatus != .authorized {
                        PillButton(title: "Allow", prominent: true) {
                            if micStatus == .notDetermined {
                                dictation.requestMicrophone()
                            } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }

            if case .failed(let message) = dictation.phase {
                Text(message).font(.system(size: 12.5)).foregroundStyle(.red).padding(.top, 12)
            }

            SectionLabel(text: "Your stats")
            HStack(spacing: 12) {
                StatTile(value: dictation.stats.totalDictations.formatted(), label: "Dictations")
                StatTile(value: dictation.stats.totalWords.formatted(), label: "Words")
                StatTile(value: "\(dictation.stats.minutesSaved) min", label: "Time saved")
            }
            Text("Wand only counts words. It never keeps what you said.")
                .font(.system(size: 12)).foregroundStyle(.tertiary).padding(.top, 10)
        }
        .onAppear { apiKey = dictation.apiKey }
        .onChange(of: dictation.provider) { _, _ in apiKey = dictation.apiKey }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        }
    }
}

private struct EngineCard: View {
    let engine: DictationEngine
    @Binding var selected: DictationEngine
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        Button { selected = engine } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: symbol).font(.title3).foregroundStyle(selected == engine ? Color.wandBlue : .primary)
                    Spacer()
                    Circle()
                        .strokeBorder(selected == engine ? Color.wandBlue : Color.primary.opacity(0.2), lineWidth: selected == engine ? 6 : 2)
                        .frame(width: 18, height: 18)
                }
                Text(title).font(.system(size: 15, weight: .semibold)).padding(.top, 12)
                Text(detail).font(.system(size: 12.5)).foregroundStyle(.secondary).padding(.top, 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 20))
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.primary.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(selected == engine ? Color.wandBlue : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: selected)
    }
}

// MARK: - Clipboard

private struct ClipboardPage: View {
    @Bindable var history: ClipboardHistory
    let openPanel: () -> Void
    @State private var confirmClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageTitle(title: "Clipboard", subtitle: "Everything you copy, one double-tap away.")

            Card {
                Toggle(isOn: $history.isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clipboard history").font(.system(size: 14, weight: .medium))
                        Text("Double-tap the right ⌥ option key anywhere to open it, then pick something to paste.")
                            .font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            Text("Saved only on this Mac and never sent anywhere. Wand skips passwords that password managers mark as private.")
                .font(.system(size: 12)).foregroundStyle(.tertiary).padding(.top, 10)

            HStack {
                Text("Recent").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                if !history.items.isEmpty {
                    PillButton(title: "Open drop-down", action: openPanel)
                    PillButton(title: "Clear history", role: .destructive) { confirmClear = true }
                }
            }
            .padding(.top, 28).padding(.bottom, 10)

            Card(padding: 0) {
                if history.items.isEmpty {
                    Text(history.isEnabled ? "Copy some text and it shows up here." : "Turn on clipboard history to start saving what you copy.")
                        .font(.system(size: 13)).foregroundStyle(.secondary).padding(20)
                }
                ForEach(Array(history.items.prefix(30).enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().padding(.leading, 20) }
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines))
                                .font(.system(size: 13.5)).lineLimit(2)
                            HStack(spacing: 6) {
                                Text(item.date, format: .relative(presentation: .named))
                                if let app = item.appName { Text("· \(app)") }
                            }
                            .font(.system(size: 11.5)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Button { history.copyToPasteboard(item) } label: { Image(systemName: "doc.on.doc") }
                            .buttonStyle(.plain).foregroundStyle(.secondary).help("Copy")
                        Button { history.remove(item) } label: { Image(systemName: "xmark") }
                            .buttonStyle(.plain).foregroundStyle(.secondary).help("Remove")
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }
            }
        }
        .confirmationDialog("Clear clipboard history?", isPresented: $confirmClear) {
            Button("Clear history", role: .destructive) { history.clear() }
        } message: {
            Text("This removes everything Wand has saved. Your current clipboard isn't changed.")
        }
    }
}

// MARK: - Shortcuts

private struct ShortcutsPage: View {
    let currentBundleId: String?

    private var allSets: [ShortcutSet] { ShortcutCatalog.sets + [ShortcutCatalog.general] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageTitle(title: "Shortcuts", subtitle: "Your iPhone shows these for the app in front. Every other app gets the General set.")
            VStack(spacing: 12) {
                ForEach(allSets.indices, id: \.self) { index in
                    let set = allSets[index]
                    let isCurrent = currentBundleId.map(set.bundleIds.contains) ?? false
                    Card {
                        HStack(spacing: 8) {
                            Text(set.name).font(.system(size: 15, weight: .semibold))
                            if isCurrent {
                                Text("In front now").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.wandBlue)
                                    .padding(.horizontal, 8).frame(height: 20)
                                    .background(Capsule().fill(Color.wandBlue.opacity(0.12)))
                            }
                            Spacer()
                            Text(appsText(set)).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        FlowChips(items: set.shortcuts.map(\.button))
                            .padding(.top, 12)
                    }
                }
            }
        }
    }

    private func appsText(_ set: ShortcutSet) -> String {
        set.bundleIds.isEmpty ? "All other apps" : "\(set.bundleIds.count) app\(set.bundleIds.count == 1 ? "" : "s")"
    }
}

/// Shortcut buttons laid out in wrapping rows.
private struct FlowChips: View {
    let items: [ShortcutButton]

    var body: some View {
        WrapLayout(spacing: 6) {
            ForEach(items) { item in
                Label(item.title, systemImage: item.symbol)
                    .font(.system(size: 12))
                    .padding(.horizontal, 10).frame(height: 26)
                    .background(Capsule().fill(Color(nsColor: .windowBackgroundColor)))
            }
        }
    }
}

private struct WrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Settings

private struct SettingsPage: View {
    let agent: Agent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageTitle(title: "Settings")

            Card(padding: 0) {
                Group {
                    Row(title: "Open Wand when I log in") {
                        Toggle("", isOn: Binding(get: { agent.opensAtLogin }, set: { agent.setOpensAtLogin($0) }))
                            .toggleStyle(.switch).labelsHidden()
                    }
                    Divider()
                    Row(title: "Set up Wand again", detail: "Walk through the welcome and permission steps again.") {
                        PillButton(title: "Start") { agent.hasCompletedSetup = false }
                    }
                }
                .padding(.horizontal, 20)
            }
            if let error = agent.lastError {
                Text(error).font(.caption).foregroundStyle(.red).padding(.top, 8)
            }

            SectionLabel(text: "Permissions")
            Card(padding: 0) {
                Group {
                    Row(title: "Type and press keys", detail: "Accessibility, for shortcuts, typing and dictation") {
                        if agent.hasAccessibility {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
                        } else {
                            PillButton(title: "Allow", prominent: true) {
                                SystemControl.requestAccessibility()
                                SystemControl.openAccessibilitySettings()
                            }
                        }
                    }
                    Divider()
                    Row(title: "Microphone", detail: "For dictation with the right ⌥ option key") {
                        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
                        } else {
                            PillButton(title: "Allow", prominent: true) { agent.dictation.requestMicrophone() }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            SectionLabel(text: "About")
            Card {
                HStack(spacing: 14) {
                    WandMark(size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wand \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Free and open source (MIT)").font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    PillButton(title: "GitHub") { NSWorkspace.shared.open(URL(string: "https://github.com/itzareous/wand")!) }
                }
            }

            HStack {
                Spacer()
                PillButton(title: "Quit Wand", role: .destructive) { NSApplication.shared.terminate(nil) }
            }
            .padding(.top, 24)
        }
    }
}

#if DEBUG
/// `-snapshotDashboard <dir>`: renders every dashboard page to PNGs for design review, then quits.
@MainActor
enum DashboardSnapshots {
    static func runIfRequested(agent: Agent) {
        guard let dir = UserDefaults.standard.string(forKey: "snapshotDashboard") else { return }
        for page in DashboardView.Page.allCases {
            let view = DashboardView(agent: agent, page: page, scrolls: false).frame(width: 920, height: 760)
                .background(Color(nsColor: .windowBackgroundColor))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("dashboard-\(page.rawValue).png"))
            }
        }
        exit(0)
    }
}
#endif
