import RemoteKit
import SwiftUI

/// Press and hold to record on the iPhone; release to have the computer transcribe and type it.
struct HoldToTalkButton: View {
    let client: RemoteClient
    /// Full-width capsule with a label, or a compact key for the Controls strip.
    var compact = false

    @State private var recorder = PhoneRecorder()
    @State private var isPressed = false

    private var ready: Bool { client.status?.dictationReady != false }

    var body: some View {
        content
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        Task {
                            do { try await recorder.start() } catch { client.report(error.localizedDescription) }
                            // Released before the microphone came up.
                            if !isPressed { finish() }
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        finish()
                    }
            )
            .sensoryFeedback(.impact(weight: .medium), trigger: recorder.isRecording)
            .accessibilityLabel("Hold to dictate")
            .accessibilityAddTraits(.isButton)
    }

    private func finish() {
        guard let audio = recorder.stop() else { return }
        client.dictate(audio)
    }

    @ViewBuilder private var content: some View {
        let active = recorder.isRecording
        HStack(spacing: 10) {
            if active {
                LevelDots(level: recorder.level)
            } else {
                Image(systemName: client.isDictating ? "ellipsis" : "mic.fill")
                    .font(compact ? .title3 : .body.weight(.semibold))
                    .symbolEffect(.pulse, isActive: client.isDictating)
            }
            if !compact {
                Text(active ? "Listening… release to type" : client.isDictating ? "Typing on your computer…" : "Hold to talk")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .foregroundStyle(active ? .black : .white)
        .frame(maxWidth: .infinity, minHeight: compact ? 52 : 56)
        .background(Capsule().fill(active ? Color.white : Color.white.opacity(0.12)))
        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(.snappy(duration: 0.15), value: active)
        .opacity(ready ? 1 : 0.5)
    }
}

private struct LevelDots: View {
    let level: Float
    private let weights: [Float] = [0.5, 0.85, 1, 0.8, 0.55]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(weights.indices, id: \.self) { index in
                Capsule()
                    .fill(.black)
                    .frame(width: 3, height: CGFloat(5 + 15 * min(1, level * weights[index] * 1.3)))
            }
        }
        .frame(height: 20)
        .animation(.easeOut(duration: 0.08), value: level)
    }
}
