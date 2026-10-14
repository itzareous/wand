import AVFoundation
import Observation

/// Records the iPhone microphone to a small AAC file for dictation on the computer.
@MainActor
@Observable
final class PhoneRecorder {
    private(set) var isRecording = false
    /// 0…1 while recording, for the button's live level.
    private(set) var level: Float = 0

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var meterTimer: Timer?
    @ObservationIgnored private var startedAt = Date()
    /// Hard cap so a stuck finger can't send a huge message.
    static let maxDuration: TimeInterval = 60

    enum RecorderError: LocalizedError {
        case microphoneDenied
        var errorDescription: String? { "Allow microphone access for Wand in Settings to dictate." }
    }

    func start() async throws {
        guard !isRecording else { return }
        guard await AVAudioApplication.requestRecordPermission() else { throw RecorderError.microphoneDenied }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("wand-\(UUID().uuidString).m4a")
        let recorder = try AVAudioRecorder(url: url, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32_000,
        ])
        recorder.isMeteringEnabled = true
        guard recorder.record(forDuration: Self.maxDuration) else { return }
        self.recorder = recorder
        startedAt = Date()
        isRecording = true
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateLevel() }
        }
    }

    /// Stops and returns the audio, or nil for a tap that was too short to be speech.
    func stop() -> Data? {
        guard let recorder, isRecording else { return nil }
        let duration = Date().timeIntervalSince(startedAt)
        recorder.stop()
        meterTimer?.invalidate()
        isRecording = false
        level = 0
        self.recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        defer { try? FileManager.default.removeItem(at: recorder.url) }
        guard duration > 0.35 else { return nil }
        return try? Data(contentsOf: recorder.url)
    }

    private func updateLevel() {
        guard let recorder else { return }
        recorder.updateMeters()
        let decibels = recorder.averagePower(forChannel: 0) // -160…0
        level = max(0, min(1, (decibels + 50) / 50))
        if !recorder.isRecording, isRecording { _ = stop() } // hit the max duration
    }
}
