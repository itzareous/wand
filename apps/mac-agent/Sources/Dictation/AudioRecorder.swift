import AVFoundation

/// Records the default microphone to a temporary AAC (.m4a) file and reports the input level.
@MainActor
final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private(set) var url: URL?
    /// 0…1, called on the main actor while recording.
    var onLevel: ((Float) -> Void)?

    func start() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wand-dictation-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderBitRateKey: 64_000,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings,
                                   commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        let onLevel = self.onLevel
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            try? file.write(from: buffer)
            let level = Self.level(of: buffer)
            DispatchQueue.main.async { onLevel?(level) }
        }
        engine.prepare()
        try engine.start()
        self.file = file
        self.url = url
    }

    /// Stops recording and returns the finished file.
    func stop() -> URL? {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        file = nil // closes the file
        defer { url = nil }
        return url
    }

    private nonisolated static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<Int(buffer.frameLength) { sum += samples[index] * samples[index] }
        let rms = (sum / Float(buffer.frameLength)).squareRoot()
        return min(1, rms * 12) // speech sits around 0.02–0.1 RMS
    }
}
