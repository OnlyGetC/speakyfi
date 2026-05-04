import Foundation
import WhisperKit

class Transcriber {
    private var whisperKit: WhisperKit?
    var onReady: (() -> Void)?
    var onProgress: ((Double, String) -> Void)?

    func loadModel() async {
        do {
            onProgress?(0.05, "Подготовка...")

            whisperKit = try await WhisperKit(
                model: "whisper-small",
                verbose: false,
                logLevel: .none,
                prewarm: false,
                load: false,
                download: true
            )

            guard let wk = whisperKit else { return }

            let modelFiles = ["AudioEncoder", "TextDecoder", "MelSpectrogram"]
            for (i, name) in modelFiles.enumerated() {
                let progress = 0.1 + Double(i) / Double(modelFiles.count) * 0.7
                onProgress?(progress, "Загрузка \(name)...")
                try await Task.sleep(nanoseconds: 100_000_000)
            }

            onProgress?(0.85, "Инициализация...")
            try await wk.loadModels()

            onProgress?(0.95, "Прогрев модели...")
            try await wk.prewarmModels()

            onProgress?(1.0, "Готово")
            onReady?()
        } catch {
            onProgress?(0.0, "Ошибка: \(error.localizedDescription)")
            print("Ошибка загрузки модели: \(error)")
        }
    }

    func transcribe(audio: [Float]) async -> String? {
        guard let whisperKit else { return nil }
        do {
            let results = try await whisperKit.transcribe(audioArray: audio)
            return results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        } catch {
            print("Ошибка транскрибации: \(error)")
            return nil
        }
    }
}
