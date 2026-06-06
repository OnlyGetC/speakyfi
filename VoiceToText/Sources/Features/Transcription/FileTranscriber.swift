import Foundation
import AVFoundation

// MARK: - Mode

enum FileTranscriptionMode {
    case local
    case deepgram
}

// MARK: - Errors

enum FileTranscriberError: LocalizedError {
    case missingDeepgramKey
    case unsupportedFileType(String)
    case httpError(Int, String)
    case invalidResponse
    case noTranscriber

    var errorDescription: String? {
        switch self {
        case .missingDeepgramKey:
            return "Deepgram API key not found. Please add it in Settings."
        case .unsupportedFileType(let ext):
            return "Unsupported file type: \(ext)"
        case .httpError(let code, let body):
            return "Deepgram HTTP \(code): \(body)"
        case .invalidResponse:
            return "Failed to parse Deepgram response"
        case .noTranscriber:
            return "Local model is not loaded yet. Please wait for the model to finish loading."
        }
    }
}

// MARK: - Deepgram response models

private struct DeepgramResponse: Decodable {
    let results: DeepgramResults
}

private struct DeepgramResults: Decodable {
    let utterances: [DeepgramUtterance]?
}

private struct DeepgramUtterance: Decodable {
    let speaker: Int
    let start: Float
    let end: Float
    let transcript: String
}

// MARK: - FileTranscriber

@MainActor
class FileTranscriber: ObservableObject {
    @Published var progress: Double = 0.0
    @Published var status: String = ""

    /// Injected from AppState — reuses the already-loaded model, avoids double loading.
    weak var transcriber: Transcriber?

    func transcribe(
        fileURL: URL,
        mode: FileTranscriptionMode,
        language: String
    ) async throws -> FileTranscriptionResult {
        switch mode {
        case .local:
            return try await transcribeLocal(fileURL: fileURL, language: language)
        case .deepgram:
            return try await transcribeDeepgram(fileURL: fileURL, language: language)
        }
    }

    // MARK: - Local (reuses the already-loaded Transcriber from AppState)

    private func transcribeLocal(fileURL: URL, language: String) async throws -> FileTranscriptionResult {
        guard let transcriber else {
            throw FileTranscriberError.noTranscriber
        }

        status = "Loading audio..."
        progress = 0.15

        let audioData = try loadAudioAsPCM(fileURL: fileURL)

        status = "Transcribing..."
        progress = 0.4

        guard let text = await transcriber.transcribe(audio: audioData, language: language) else {
            return FileTranscriptionResult(segments: [], hasSpeakers: false)
        }

        progress = 1.0
        status = "Done"

        // Local transcription via Transcriber returns plain text without timestamps.
        // We present it as a single segment.
        let segment = FileTranscriptionSegment(start: 0, end: 0, text: text, speaker: nil)
        return FileTranscriptionResult(segments: [segment], hasSpeakers: false)
    }

    private func loadAudioAsPCM(fileURL: URL) throws -> [Float] {
        // Convert any audio/video file to 16kHz mono Float32 PCM required by Whisper
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        let sourceFile = try AVAudioFile(forReading: fileURL)
        let sourceFormat = sourceFile.processingFormat
        let frameCount = AVAudioFrameCount(sourceFile.length)

        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
            return []
        }
        try sourceFile.read(into: sourceBuffer)

        guard let converter = AVAudioConverter(from: sourceFormat, to: outputFormat) else {
            return []
        }

        let targetFrameCount = AVAudioFrameCount(Double(frameCount) * 16000 / sourceFormat.sampleRate)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: targetFrameCount) else {
            return []
        }

        var error: NSError?
        var inputConsumed = false
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if let error { throw error }
        let channelData = outputBuffer.floatChannelData![0]
        return Array(UnsafeBufferPointer(start: channelData, count: Int(outputBuffer.frameLength)))
    }

    // MARK: - Deepgram (with diarization)

    private func transcribeDeepgram(fileURL: URL, language: String) async throws -> FileTranscriptionResult {
        guard let apiKey = KeychainHelper.load(key: CloudProvider.deepgram.keychainKey), !apiKey.isEmpty else {
            throw FileTranscriberError.missingDeepgramKey
        }

        status = "Reading file..."
        progress = 0.1

        let fileData = try Data(contentsOf: fileURL)
        let mimeType = mimeType(for: fileURL.pathExtension.lowercased())

        status = "Uploading to Deepgram..."
        progress = 0.3

        var urlComponents = URLComponents(string: "https://api.deepgram.com/v1/listen")!
        var queryItems = [
            URLQueryItem(name: "model", value: "nova-2"),
            URLQueryItem(name: "diarize", value: "true"),
            URLQueryItem(name: "utterances", value: "true"),
            URLQueryItem(name: "punctuate", value: "true")
        ]
        if language != "auto" {
            queryItems.append(URLQueryItem(name: "language", value: language))
        }
        urlComponents.queryItems = queryItems

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.httpBody = fileData

        progress = 0.5
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw FileTranscriberError.invalidResponse
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw FileTranscriberError.httpError(http.statusCode, body)
        }

        status = "Parsing response..."
        progress = 0.9

        let decoded = try JSONDecoder().decode(DeepgramResponse.self, from: data)
        let utterances = decoded.results.utterances ?? []

        let segments: [FileTranscriptionSegment] = utterances.map { u in
            FileTranscriptionSegment(
                start: u.start,
                end: u.end,
                text: u.transcript.trimmingCharacters(in: .whitespaces),
                speaker: u.speaker
            )
        }

        progress = 1.0
        status = "Done"

        return FileTranscriptionResult(segments: segments, hasSpeakers: true)
    }

    // MARK: - Helpers

    private func mimeType(for ext: String) -> String {
        switch ext {
        case "mp3":  return "audio/mpeg"
        case "mp4":  return "video/mp4"
        case "wav":  return "audio/wav"
        case "m4a":  return "audio/mp4"
        case "mov":  return "video/quicktime"
        default:     return "application/octet-stream"
        }
    }
}
