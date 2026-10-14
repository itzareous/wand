import RemoteKit
import SwiftUI

/// The part of the Touch Bar that changes with the app in front on the computer.
struct AppShortcutsView: View {
    let context: AppContext
    /// Landscape: one scrolling strip. Portrait: a grid.
    let isCompact: Bool
    let onTap: (ShortcutButton) -> Void

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if isCompact {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { buttons }
                }
            } else {
                LazyVGrid(columns: columns, spacing: 8) { buttons }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(white: 0.08)))
        .animation(.snappy(duration: 0.25), value: context.bundleId)
    }

    private var header: some View {
        HStack(spacing: 10) {
            AppIcon(data: context.icon)
                .frame(width: 28, height: 28)
            Text(context.appName)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if context.setName != context.appName {
                Text(context.setName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .id(context.bundleId)
        .transition(.opacity)
    }

    @ViewBuilder private var buttons: some View {
        ForEach(context.shortcuts) { shortcut in
            Button { onTap(shortcut) } label: {
                VStack(spacing: 4) {
                    Image(systemName: shortcut.symbol)
                        .font(.body)
                    Text(shortcut.title)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: isCompact ? nil : .infinity, minHeight: 52)
                .padding(.horizontal, isCompact ? 16 : 6)
            }
            .buttonStyle(ShortcutKeyStyle())
            .accessibilityLabel(shortcut.title)
        }
    }
}

private struct ShortcutKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.3 : 0.12)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct AppIcon: View {
    let data: Data?

    var body: some View {
        if let image = data.flatMap(Self.image(from:)) {
            image.resizable().interpolation(.high).aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "app.dashed").resizable().aspectRatio(contentMode: .fit).foregroundStyle(.secondary)
        }
    }

    private static func image(from data: Data) -> Image? {
        #if canImport(UIKit)
        UIImage(data: data).map(Image.init(uiImage:))
        #else
        NSImage(data: data).map(Image.init(nsImage:))
        #endif
    }
}
