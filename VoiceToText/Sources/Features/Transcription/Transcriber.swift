import Foundation

#if arch(arm64)
import WhisperKit

class Transcriber {
    private var whisperKit: WhisperKit?
    private var currentModel: LocalWhisperModel = .small
    var onReady: (() -> Void)?
    var onProgress: ((Double, String) -> Void)?

    func loadModel(_ model: LocalWhisperModel = .small) async {
        currentModel = model
        do {
            onProgress?(0.05, "Подготовка...")

            whisperKit = try await WhisperKit(
                model: model.rawValue,
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

    /// Сменить модель на лету (без перезапуска приложения)
    func switchModel(to model: LocalWhisperModel) async {
        whisperKit = nil
        onProgress?(0.0, "Смена модели...")
        await loadModel(model)
    }

    func transcribe(audio: [Float], language: String = "ru", prompt: String? = nil) async -> String? {
        guard let whisperKit else { return nil }
        do {
            var options = DecodingOptions()
            if language != "auto" {
                options.language = language
            }
            options.task = .transcribe
            if let prompt, !prompt.isEmpty {
                options.promptTokens = whisperKit.tokenizer?.encode(text: " \(prompt)") ?? []
            }

            let results = try await whisperKit.transcribe(audioArray: audio, decodeOptions: options)
            return results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        } catch {
            print("Ошибка транскрибации: \(error)")
            return nil
        }
    }
}

#else

class Transcriber {
    private let backend = WhisperCppBackend()
    private var currentModel: LocalWhisperModel = .small
    var onReady: (() -> Void)?
    var onProgress: ((Double, String) -> Void)?

    private func intelModel(for model: LocalWhisperModel) -> IntelWhisperModel {
        switch model {
        case .tiny:   return .tiny
        case .base:   return .base
        case .small:  return .small
        case .medium: return .medium
        case .large:  return .medium
        }
    }

    func loadModel(_ model: LocalWhisperModel = .small) async {
        currentModel = model
        backend.onProgress = { [weak self] progress, label in
            self?.onProgress?(progress, label)
        }
        await backend.loadModel(intelModel(for: model))
        onReady?()
    }

    func switchModel(to model: LocalWhisperModel) async {
        onProgress?(0.0, "Смена модели...")
        await loadModel(model)
    }

    func transcribe(audio: [Float], language: String = "ru", prompt: String? = nil) async -> String? {
        await backend.transcribe(audio: audio, language: language, prompt: prompt)
    }
}

#endif
