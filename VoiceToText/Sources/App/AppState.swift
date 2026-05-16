import Foundation
import Combine

// MARK: - Провайдер транскрибации

enum TranscriptionProvider: String {
    case local = "local"
    case cloud = "cloud"
}

// MARK: - AppState

class AppState: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var isTranscribing: Bool = false
    @Published var isVADMode: Bool = false
    @Published var modelReady: Bool = false
    @Published var modelLoading: Bool = true
    @Published var modelProgress: Double = 0.0
    @Published var modelProgressLabel: String = ""
    @Published var audioLevel: Float = 0.0
    @Published var history: [TranscriptionEntry] = []
    @Published var lastText: String = ""

    // Настройки транскрибации
    @Published var transcriptionLanguage: String {
        didSet { UserDefaults.standard.set(transcriptionLanguage, forKey: "transcriptionLanguage") }
    }
    @Published var transcriptionPrompt: String {
        didSet { UserDefaults.standard.set(transcriptionPrompt, forKey: "transcriptionPrompt") }
    }
    @Published var promptEnabled: Bool {
        didSet { UserDefaults.standard.set(promptEnabled, forKey: "promptEnabled") }
    }

    // Настройки модели
    @Published var transcriptionProvider: TranscriptionProvider {
        didSet { UserDefaults.standard.set(transcriptionProvider.rawValue, forKey: "transcriptionProvider") }
    }
    @Published var selectedLocalModel: LocalWhisperModel {
        didSet {
            UserDefaults.standard.set(selectedLocalModel.rawValue, forKey: "selectedLocalModel")
        }
    }
    @Published var selectedCloudProvider: CloudProvider {
        didSet { UserDefaults.standard.set(selectedCloudProvider.rawValue, forKey: "selectedCloudProvider") }
    }

    // Флаг — идёт ли смена модели
    @Published var isModelSwitching: Bool = false

    // Настройки коррекции текста
    @Published var correctionMode: CorrectionMode {
        didSet { UserDefaults.standard.set(correctionMode.rawValue, forKey: "correctionMode") }
    }
    @Published var correctionApiProvider: CorrectionApiProvider {
        didSet { UserDefaults.standard.set(correctionApiProvider.rawValue, forKey: "correctionApiProvider") }
    }
    @Published var correctionOllamaModel: String {
        didSet { UserDefaults.standard.set(correctionOllamaModel, forKey: "correctionOllamaModel") }
    }
    @Published var correctionPrompt: String {
        didSet { UserDefaults.standard.set(correctionPrompt, forKey: "correctionPrompt") }
    }
    @Published var correctionCustomEndpoint: String {
        didSet { UserDefaults.standard.set(correctionCustomEndpoint, forKey: "correctionCustomEndpoint") }
    }

    let recorder = AudioRecorder()
    let transcriber = Transcriber()
    let cloudTranscriber = CloudTranscriber()
    let correctionService = TextCorrectionService()

    init() {
        self.transcriptionLanguage = UserDefaults.standard.string(forKey: "transcriptionLanguage") ?? "ru"
        self.transcriptionPrompt = UserDefaults.standard.string(forKey: "transcriptionPrompt") ?? t(.promptDefaultText)
        self.promptEnabled = UserDefaults.standard.object(forKey: "promptEnabled") as? Bool ?? false

        let providerRaw = UserDefaults.standard.string(forKey: "transcriptionProvider") ?? "local"
        self.transcriptionProvider = TranscriptionProvider(rawValue: providerRaw) ?? .local

        let modelRaw = UserDefaults.standard.string(forKey: "selectedLocalModel") ?? LocalWhisperModel.small.rawValue
        self.selectedLocalModel = LocalWhisperModel(rawValue: modelRaw) ?? .small

        let cloudRaw = UserDefaults.standard.string(forKey: "selectedCloudProvider") ?? CloudProvider.openai.rawValue
        self.selectedCloudProvider = CloudProvider(rawValue: cloudRaw) ?? .openai

        let correctionRaw = UserDefaults.standard.string(forKey: "correctionMode") ?? CorrectionMode.off.rawValue
        self.correctionMode = CorrectionMode(rawValue: correctionRaw) ?? .off

        let correctionProviderRaw = UserDefaults.standard.string(forKey: "correctionApiProvider") ?? CorrectionApiProvider.groq.rawValue
        self.correctionApiProvider = CorrectionApiProvider(rawValue: correctionProviderRaw) ?? .groq

        self.correctionOllamaModel = UserDefaults.standard.string(forKey: "correctionOllamaModel") ?? "llama3.2"
        self.correctionPrompt = UserDefaults.standard.string(forKey: "correctionPrompt") ?? defaultCorrectionPrompt
        self.correctionCustomEndpoint = UserDefaults.standard.string(forKey: "correctionCustomEndpoint") ?? ""

        transcriber.onReady = { [weak self] in
            DispatchQueue.main.async {
                self?.modelReady = true
                self?.modelLoading = false
                self?.modelProgress = 1.0
                self?.isModelSwitching = false
            }
        }
        transcriber.onProgress = { [weak self] progress, label in
            DispatchQueue.main.async {
                self?.modelProgress = progress
                self?.modelProgressLabel = label
            }
        }
        recorder.onLevelUpdate = { [weak self] level in
            DispatchQueue.main.async {
                self?.audioLevel = level
            }
        }
    }

    func addHistory(text: String) {
        let entry = TranscriptionEntry(text: text, timestamp: Date())
        history.insert(entry, at: 0)
        lastText = text
        if history.count > 50 {
            history.removeLast()
        }
    }

    /// Сменить локальную модель на лету
    func switchLocalModel(to model: LocalWhisperModel) {
        guard model != selectedLocalModel else { return }
        selectedLocalModel = model
        modelReady = false
        isModelSwitching = true
        modelLoading = true
        Task {
            await transcriber.switchModel(to: model)
        }
    }
}

// MARK: - TranscriptionEntry

struct TranscriptionEntry: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: timestamp)
    }
}

// MARK: - Языки Whisper

struct WhisperLanguage: Identifiable, Hashable {
    let id: String
    let name: String

    static let all: [WhisperLanguage] = [
        .init(id: "auto", name: t(.langAuto)),
        .init(id: "ru", name: "Русский"),
        .init(id: "en", name: "English"),
        .init(id: "zh", name: "中文 (Chinese)"),
        .init(id: "de", name: "Deutsch"),
        .init(id: "es", name: "Español"),
        .init(id: "fr", name: "Français"),
        .init(id: "it", name: "Italiano"),
        .init(id: "pt", name: "Português"),
        .init(id: "nl", name: "Nederlands"),
        .init(id: "pl", name: "Polski"),
        .init(id: "uk", name: "Українська"),
        .init(id: "cs", name: "Čeština"),
        .init(id: "sk", name: "Slovenčina"),
        .init(id: "ro", name: "Română"),
        .init(id: "hu", name: "Magyar"),
        .init(id: "bg", name: "Български"),
        .init(id: "hr", name: "Hrvatski"),
        .init(id: "sr", name: "Српски"),
        .init(id: "sv", name: "Svenska"),
        .init(id: "da", name: "Dansk"),
        .init(id: "fi", name: "Suomi"),
        .init(id: "nb", name: "Norsk"),
        .init(id: "tr", name: "Türkçe"),
        .init(id: "ar", name: "العربية"),
        .init(id: "fa", name: "فارسی"),
        .init(id: "he", name: "עברית"),
        .init(id: "hi", name: "हिन्दी"),
        .init(id: "ja", name: "日本語"),
        .init(id: "ko", name: "한국어"),
        .init(id: "th", name: "ภาษาไทย"),
        .init(id: "vi", name: "Tiếng Việt"),
        .init(id: "id", name: "Bahasa Indonesia"),
        .init(id: "ms", name: "Bahasa Melayu"),
        .init(id: "ca", name: "Català"),
        .init(id: "af", name: "Afrikaans"),
        .init(id: "sq", name: "Shqip"),
        .init(id: "am", name: "አማርኛ"),
        .init(id: "hy", name: "Հայերեն"),
        .init(id: "az", name: "Azərbaycan"),
        .init(id: "be", name: "Беларуская"),
        .init(id: "bn", name: "বাংলা"),
        .init(id: "bs", name: "Bosanski"),
        .init(id: "et", name: "Eesti"),
        .init(id: "gl", name: "Galego"),
        .init(id: "ka", name: "ქართული"),
        .init(id: "el", name: "Ελληνικά"),
        .init(id: "gu", name: "ગુજરાતી"),
        .init(id: "ht", name: "Kreyòl ayisyen"),
        .init(id: "ha", name: "Hausa"),
        .init(id: "haw", name: "ʻŌlelo Hawaiʻi"),
        .init(id: "is", name: "Íslenska"),
        .init(id: "kn", name: "ಕನ್ನಡ"),
        .init(id: "kk", name: "Қазақша"),
        .init(id: "km", name: "ខ្មែរ"),
        .init(id: "lo", name: "ລາວ"),
        .init(id: "lv", name: "Latviešu"),
        .init(id: "lt", name: "Lietuvių"),
        .init(id: "lb", name: "Lëtzebuergesch"),
        .init(id: "mk", name: "Македонски"),
        .init(id: "mg", name: "Malagasy"),
        .init(id: "ml", name: "മലയാളം"),
        .init(id: "mt", name: "Malti"),
        .init(id: "mi", name: "Māori"),
        .init(id: "mr", name: "मराठी"),
        .init(id: "mn", name: "Монгол"),
        .init(id: "my", name: "မြန်မာ"),
        .init(id: "ne", name: "नेपाली"),
        .init(id: "ps", name: "پښتو"),
        .init(id: "pa", name: "ਪੰਜਾਬੀ"),
        .init(id: "si", name: "සිංහල"),
        .init(id: "sl", name: "Slovenščina"),
        .init(id: "so", name: "Soomaali"),
        .init(id: "su", name: "Basa Sunda"),
        .init(id: "sw", name: "Kiswahili"),
        .init(id: "tl", name: "Filipino"),
        .init(id: "tg", name: "Тоҷикӣ"),
        .init(id: "ta", name: "தமிழ்"),
        .init(id: "tt", name: "Татарча"),
        .init(id: "te", name: "తెలుగు"),
        .init(id: "tk", name: "Türkmençe"),
        .init(id: "ur", name: "اردو"),
        .init(id: "uz", name: "Oʻzbekcha"),
        .init(id: "cy", name: "Cymraeg"),
        .init(id: "yi", name: "ייִדיש"),
        .init(id: "yo", name: "Yorùbá"),
    ]
}
