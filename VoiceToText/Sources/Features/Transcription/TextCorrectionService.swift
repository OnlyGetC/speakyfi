import Foundation

// MARK: - Режим коррекции

enum CorrectionMode: String, CaseIterable {
    case off    = "off"
    case ollama = "ollama"
    case api    = "api"

    var displayName: String {
        switch self {
        case .off:    return "Выключено"
        case .ollama: return "Локально (Ollama)"
        case .api:    return "API"
        }
    }
}

// MARK: - API провайдер для коррекции

enum CorrectionApiProvider: String, CaseIterable, Identifiable {
    case openai  = "openai"
    case groq    = "groq"
    case custom  = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai:  return "OpenAI"
        case .groq:    return "Groq"
        case .custom:  return "Свой эндпоинт"
        }
    }

    var defaultModel: String {
        switch self {
        case .openai:  return "gpt-4o-mini"
        case .groq:    return "llama-3.1-8b-instant"
        case .custom:  return ""
        }
    }

    // Ключ в Keychain — переиспользуем уже существующие ключи от CloudTranscriber
    var keychainKey: String {
        switch self {
        case .openai:  return "com.voicetotext.apikey.openai"
        case .groq:    return "com.voicetotext.apikey.groq"
        case .custom:  return "com.voicetotext.apikey.correction.custom"
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .openai:  return "https://api.openai.com/v1/chat/completions"
        case .groq:    return "https://api.groq.com/openai/v1/chat/completions"
        case .custom:  return ""
        }
    }
}

// MARK: - Промт по умолчанию

let defaultCorrectionPrompt = """
Исправь ошибки транскрибации в тексте. Правила:
- Технические термины, названия и англицизмы пиши на языке оригинала: git, JSON, API, OK, Swift, Docker и т.д.
- Не убирай слова-паразиты и не меняй стиль речи
- Исправляй только явные ошибки распознавания речи
- Верни только исправленный текст, без пояснений
"""

// MARK: - TextCorrectionService

class TextCorrectionService {

    func correct(text: String, mode: CorrectionMode, prompt: String, apiProvider: CorrectionApiProvider, ollamaModel: String, customEndpoint: String) async -> String {
        guard mode != .off, !text.isEmpty else { return text }

        switch mode {
        case .off:
            return text
        case .ollama:
            return await correctViaOllama(text: text, prompt: prompt, model: ollamaModel)
        case .api:
            return await correctViaAPI(text: text, prompt: prompt, provider: apiProvider, customEndpoint: customEndpoint)
        }
    }

    // MARK: - Ollama

    private func correctViaOllama(text: String, prompt: String, model: String) async -> String {
        let url = URL(string: "http://localhost:11434/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model.isEmpty ? "llama3.2" : model,
            "stream": false,
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user",   "content": text]
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return text }
        request.httpBody = data

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                print("TextCorrectionService [Ollama] HTTP error")
                return text
            }
            guard
                let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                let message = json["message"] as? [String: Any],
                let content = message["content"] as? String
            else { return text }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("TextCorrectionService [Ollama] error: \(error)")
            return text
        }
    }

    // MARK: - API (OpenAI-совместимый)

    private func correctViaAPI(text: String, prompt: String, provider: CorrectionApiProvider, customEndpoint: String) async -> String {
        let apiKey = KeychainHelper.load(key: provider.keychainKey) ?? ""
        guard !apiKey.isEmpty else {
            print("TextCorrectionService [\(provider.displayName)] API-ключ не задан")
            return text
        }

        let endpointString = provider == .custom
            ? (customEndpoint.isEmpty ? provider.defaultEndpoint : customEndpoint)
            : provider.defaultEndpoint
        guard let url = URL(string: endpointString) else { return text }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let model = provider.defaultModel
        let body: [String: Any] = [
            "model": model,
            "temperature": 0.1,
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user",   "content": text]
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return text }
        request.httpBody = data

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let msg = String(data: responseData, encoding: .utf8) ?? "unknown"
                print("TextCorrectionService [\(provider.displayName)] HTTP error: \(msg)")
                return text
            }
            guard
                let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let first = choices.first,
                let message = first["message"] as? [String: Any],
                let content = message["content"] as? String
            else { return text }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("TextCorrectionService [\(provider.displayName)] error: \(error)")
            return text
        }
    }
}
