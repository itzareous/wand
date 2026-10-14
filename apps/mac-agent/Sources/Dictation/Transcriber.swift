import Foundation
import Speech

/// Where speech becomes text.
enum DictationEngine: String, CaseIterable, Identifiable {
    case cloud
    case onDevice
    var id: Self { self }
    var title: String {
        switch self {
        case .cloud: "Cloud (most accurate)"
        case .onDevice: "On this Mac (private, free)"
        }
    }
}

/// Any OpenAI-compatible `/audio/transcriptions` endpoint.
enum CloudProvider: String, CaseIterable, Identifiable {
    case openAI, groq, custom
    var id: Self { self }
    var title: String {
        switch self {
        case .openAI: "OpenAI"
        case .groq: "Groq"
        case .custom: "Custom (OpenAI-compatible)"
        }
    }
    var defaultBaseURL: String {
        switch self {
        case .openAI: "https://api.openai.com/v1"
        case .groq: "https://api.groq.com/openai/v1"
        case .custom: ""
        }
    }
    var defaultModel: String {
        switch self {
        case .openAI: "whisper-1"
        case .groq: "whisper-large-v3-turbo"
        case .custom: "whisper-1"
        }
    }
    var keychainAccount: String { "dictation.apiKey.\(rawValue)" }
}

enum TranscriptionError: LocalizedError {
    case missingAPIKey
    case badURL
    case server(String)
    case speechNotAllowed
    case speechUnavailable

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "Add your API key in Wand → Dictation, or switch to On this Mac."
        case .badURL: "The API URL in Wand → Dictation isn't valid."
        case .server(let message): message
        case .speechNotAllowed: "Allow Speech Recognition for Wand in System Settings → Privacy & Security."
        case .speechUnavailable: "On-device speech recognition isn't available for your language on this Mac."
        }
    }
}

enum CloudTranscriber {
    static func transcribe(fileAt url: URL, baseURL: String, model: String, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else { throw TranscriptionError.missingAPIKey }
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let endpoint = URL(string: trimmed + "/audio/transcriptions"), endpoint.scheme?.hasPrefix("http") == true else {
            throw TranscriptionError.badURL
        }
        let boundary = "wand-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        field("model", model)
        field("response_format", "json")
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"dictation.m4a\"\r\nContent-Type: audio/m4a\r\n\r\n".utf8))
        body.append(try Data(contentsOf: url))
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let detail = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error.message
                ?? String(decoding: data.prefix(200), as: UTF8.self)
            throw TranscriptionError.server("Transcription failed (\(status)): \(detail)")
        }
        return try JSONDecoder().decode(TextBody.self, from: data).text
    }

    private struct TextBody: Decodable { let text: String }
    private struct ErrorBody: Decodable {
        struct Inner: Decodable { let message: String }
        let error: Inner
    }
}

enum OnDeviceTranscriber {
    static func transcribe(fileAt url: URL) async throws -> String {
        guard await requestAuthorization() else { throw TranscriptionError.speechNotAllowed }
        guard let recognizer = SFSpeechRecognizer(locale: .current) ?? SFSpeechRecognizer(),
              recognizer.isAvailable else { throw TranscriptionError.speechUnavailable }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.addsPunctuation = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !finished else { return }
                if let error {
                    finished = true
                    continuation.resume(throwing: error)
                } else if let result, result.isFinal {
                    finished = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    static func requestAuthorization() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }
}
