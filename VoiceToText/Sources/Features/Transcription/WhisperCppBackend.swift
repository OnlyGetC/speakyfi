#if !arch(arm64)
import Foundation
import SwiftWhisper

class WhisperCppBackend {
    private var whisper: Whisper?
    var onProgress: ((Double, String) -> Void)?

    private var modelsDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("speakyfi-models")
    }

    func loadModel(_ model: IntelWhisperModel) async {
        let modelURL = modelsDirectory.appendingPathComponent(model.fileName)

        if !FileManager.default.fileExists(atPath: modelURL.path) {
            await downloadModel(model, to: modelURL)
        }

        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            onProgress?(0.0, "Ошибка: файл модели не найден")
            return
        }

        onProgress?(0.9, "Инициализация модели...")
        whisper = Whisper(fromFileURL: modelURL)
        onProgress?(1.0, "Готово")
    }

    private func downloadModel(_ model: IntelWhisperModel, to destination: URL) async {
        onProgress?(0.05, "Загрузка \(model.displayName)...")

        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        let tmpURL = destination.appendingPathExtension("tmp")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        do {
            let (data, response) = try await URLSession.shared.data(from: model.downloadURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                onProgress?(0.0, "Ошибка загрузки модели")
                return
            }
            try data.write(to: tmpURL)
            try FileManager.default.moveItem(at: tmpURL, to: destination)
            onProgress?(0.85, "Загрузка завершена")
        } catch {
            onProgress?(0.0, "Ошибка загрузки: \(error.localizedDescription)")
        }
    }

    func transcribe(audio: [Float], language: String, prompt: String?) async -> String? {
        guard let whisper else { return nil }
        do {
            let segments = try await whisper.transcribe(audioFrames: audio)
            return segments.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        } catch {
            print("Ошибка транскрибации: \(error)")
            return nil
        }
    }
}
#endif
