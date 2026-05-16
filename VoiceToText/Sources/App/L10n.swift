import Foundation
import SwiftUI

// MARK: - Language

enum AppLanguage: String, CaseIterable, Identifiable {
    case en = "en"
    case ru = "ru"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        }
    }
}

// MARK: - L10n

/// Глобальная функция локализации. Использует AppStorage через L10nState.
func t(_ key: L10n) -> String {
    L10nState.shared.string(for: key)
}

// MARK: - L10nState (ObservableObject для реактивного обновления UI)

final class L10nState: ObservableObject {
    static let shared = L10nState()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        self.language = AppLanguage(rawValue: raw) ?? .en
    }

    func string(for key: L10n) -> String {
        switch language {
        case .en: return key.en
        case .ru: return key.ru
        }
    }
}

// MARK: - L10n Keys

enum L10n {
    // MARK: Settings sidebar
    case settingsTitle
    case settingsSupportButton

    // MARK: Settings sections
    case sectionHotkeys
    case sectionModel
    case sectionLanguage
    case sectionPrompt
    case sectionCorrection
    case sectionInterface

    // MARK: Settings section info
    case infoHotkeys
    case infoModel
    case infoLanguage
    case infoPrompt
    case infoCorrection
    case infoInterface

    // MARK: Hotkeys section
    case hotkeyPTT
    case hotkeyVAD
    case hotkeyHint
    case hotkeyReset
    case hotkeyPressKey

    // MARK: Model section
    case modelLocal
    case modelCloud
    case modelLoading
    case modelActive
    case modelSelect
    case modelDownload
    case modelApiKeyFor
    case modelSave
    case modelKeychainNote
    case modelKeySet

    // MARK: Language section
    case langTitle
    case langHint
    case langAuto

    // MARK: Prompt section
    case promptTitle
    case promptReset
    case promptDisabledHint
    case promptDefaultText

    // MARK: Correction section
    case correctionTitle
    case correctionPromptLabel
    case correctionPromptReset
    case correctionOffDescription
    case correctionOllamaDescription
    case correctionApiDescription
    case correctionInstallOllama
    case correctionDownloadModel
    case correctionLoadingModel
    case correctionOllamaModelLabel
    case correctionApiKeyLabel
    case correctionSave
    case correctionKeychainNote
    case correctionGroqHint
    case correctionOllamaStatusNotInstalled
    case correctionOllamaStatusInstalling
    case correctionOllamaStatusInstallError
    case correctionOllamaStatusStopped
    case correctionOllamaStatusStarting
    case correctionOllamaStatusStopping
    case correctionOllamaStatusServerError
    case correctionOllamaStatusReady
    case correctionOllamaStatusPulling
    case correctionOllamaStatusNotPulled
    case correctionOllamaStatusModelError
    case correctionModelError
    case correctionInstallError
    case correctionPromptInfoHint

    // MARK: Interface section
    case interfaceTitle
    case interfaceLanguageLabel

    // MARK: Overlay
    case overlayStatusLoading
    case overlayStatusRecording
    case overlayStatusVADRecording
    case overlayStatusTranscribing
    case overlayStatusDone
    case overlayStatusVADListening
    case overlayStatusReady
    case overlayTranscribing
    case overlayCopy
    case overlayCopied
    case overlayInserted
    case overlayHoldToRecord

    // MARK: History
    case historyTitle
    case historyEmpty

    // MARK: Donate
    case donateTitle
    case donateCaption
    case donateCopyAddress

    // MARK: Splash
    case splashSupport

    // MARK: Menu (AppDelegate)
    case menuShow
    case menuMode
    case menuSettings
    case menuQuit
}

// MARK: - Translations

extension L10n {
    var en: String {
        switch self {
        // Settings sidebar
        case .settingsTitle:              return "Settings"
        case .settingsSupportButton:      return "Support"

        // Settings sections
        case .sectionHotkeys:             return "Hotkeys"
        case .sectionModel:               return "Model"
        case .sectionLanguage:            return "Language"
        case .sectionPrompt:              return "Prompt"
        case .sectionCorrection:          return "Correction"
        case .sectionInterface:           return "Interface"

        // Settings section info
        case .infoHotkeys:
            return "Assign keys for Push-to-Talk (hold to record) and toggling VAD mode (auto voice detection)."
        case .infoModel:
            return "Choose transcription method: local WhisperKit model works offline, cloud APIs require internet and a key."
        case .infoLanguage:
            return "Language you speak in. Affects recognition quality. \"Auto\" lets Whisper detect language automatically."
        case .infoPrompt:
            return "A hint passed to the Whisper model before transcription. Helps recognize terms, names and mixed ru+en text."
        case .infoCorrection:
            return "Post-processing via LLM after transcription. Fixes recognition errors and restores anglicisms. Off by default."
        case .infoInterface:
            return "Interface display language."

        // Hotkeys section
        case .hotkeyPTT:                  return "PTT (hold)"
        case .hotkeyVAD:                  return "Toggle VAD"
        case .hotkeyHint:                 return "Click the button → press a key (or hold a modifier and release). Esc to cancel."
        case .hotkeyReset:                return "Reset to default"
        case .hotkeyPressKey:             return "Press a key..."

        // Model section
        case .modelLocal:                 return "Local"
        case .modelCloud:                 return "Cloud (API)"
        case .modelLoading:               return "loading..."
        case .modelActive:                return "Active"
        case .modelSelect:                return "Select"
        case .modelDownload:              return "Download"
        case .modelApiKeyFor:             return "API key for"
        case .modelSave:                  return "Save"
        case .modelKeychainNote:          return "Key is stored in Keychain and never leaves the device."
        case .modelKeySet:                return "key set"

        // Language section
        case .langTitle:                  return "Transcription Language"
        case .langHint:                   return "Select speech language. \"Auto\" is slower but detects language automatically."
        case .langAuto:                   return "Auto (detect)"

        // Prompt section
        case .promptTitle:                return "Whisper Prompt"
        case .promptReset:                return "Reset"
        case .promptDisabledHint:         return "Enable to add a hint for the Whisper model."
        case .promptDefaultText:          return "Text may contain technical terms in English."

        // Correction section
        case .correctionTitle:            return "Text Correction"
        case .correctionPromptLabel:      return "CORRECTION PROMPT"
        case .correctionPromptReset:      return "Reset"
        case .correctionOffDescription:   return "Text is inserted as-is after transcription"
        case .correctionOllamaDescription: return "Locally, no internet. Adds ~1–3 sec, uses RAM"
        case .correctionApiDescription:   return "Requires internet and API key. Fast but network-dependent"
        case .correctionInstallOllama:    return "Install Ollama"
        case .correctionDownloadModel:    return "Download model"
        case .correctionLoadingModel:     return "Downloading model..."
        case .correctionOllamaModelLabel: return "Model:"
        case .correctionApiKeyLabel:      return "API key"
        case .correctionSave:             return "Save"
        case .correctionKeychainNote:     return "Key is stored in Keychain and never leaves the device."
        case .correctionGroqHint:         return "Groq offers a free tier — groq.com"
        case .correctionOllamaStatusNotInstalled: return "not installed"
        case .correctionOllamaStatusInstalling:   return "installing..."
        case .correctionOllamaStatusInstallError: return "install error"
        case .correctionOllamaStatusStopped:      return "stopped"
        case .correctionOllamaStatusStarting:     return "starting..."
        case .correctionOllamaStatusStopping:     return "stopping..."
        case .correctionOllamaStatusServerError:  return "server error"
        case .correctionOllamaStatusReady:        return "ready"
        case .correctionOllamaStatusPulling:      return "downloading model..."
        case .correctionOllamaStatusNotPulled:    return "model not downloaded"
        case .correctionOllamaStatusModelError:   return "model error"
        case .correctionModelError:               return "Model error: "
        case .correctionInstallError:             return "Install error: "
        case .correctionPromptInfoHint:
            return "Instruction for the LLM. Defines what to correct. Can be customized to your needs."

        // Interface section
        case .interfaceTitle:             return "Interface"
        case .interfaceLanguageLabel:     return "Language"

        // Overlay
        case .overlayStatusLoading:       return "Loading model..."
        case .overlayStatusRecording:     return "Recording"
        case .overlayStatusVADRecording:  return "VAD · Recording"
        case .overlayStatusTranscribing:  return "Transcribing..."
        case .overlayStatusDone:          return "Done"
        case .overlayStatusVADListening:  return "VAD · Listening"
        case .overlayStatusReady:         return "Ready to record"
        case .overlayTranscribing:        return "Transcribing..."
        case .overlayCopy:                return "Copy"
        case .overlayCopied:              return "Copied"
        case .overlayInserted:            return "inserted"
        case .overlayHoldToRecord:        return "Hold %@ to record"

        // History
        case .historyTitle:               return "History"
        case .historyEmpty:               return "No records"

        // Donate
        case .donateTitle:                return "Support"
        case .donateCaption:              return "Support the author to feed this chonk"
        case .donateCopyAddress:          return "Copy address"

        // Splash
        case .splashSupport:              return "Support"

        // Menu
        case .menuShow:                   return "Show"
        case .menuMode:                   return "Mode: PTT / VAD"
        case .menuSettings:               return "Settings..."
        case .menuQuit:                   return "Quit"
        }
    }

    var ru: String {
        switch self {
        // Settings sidebar
        case .settingsTitle:              return "Настройки"
        case .settingsSupportButton:      return "Поддержать"

        // Settings sections
        case .sectionHotkeys:             return "Хоткеи"
        case .sectionModel:               return "Модель"
        case .sectionLanguage:            return "Язык"
        case .sectionPrompt:              return "Промт"
        case .sectionCorrection:          return "Коррекция"
        case .sectionInterface:           return "Интерфейс"

        // Settings section info
        case .infoHotkeys:
            return "Назначьте клавиши для Push-to-Talk (удерживать для записи) и переключения режима VAD (автоопределение речи)."
        case .infoModel:
            return "Выберите способ транскрибации: локальная модель WhisperKit работает без интернета, облачные API требуют подключения и ключа."
        case .infoLanguage:
            return "Язык, на котором говорите. Влияет на качество распознавания. «Авто» — Whisper определит язык самостоятельно."
        case .infoPrompt:
            return "Подсказка передаётся в модель Whisper до транскрибации. Помогает правильно распознавать термины, имена и смешанный текст ru+en."
        case .infoCorrection:
            return "Постобработка текста через LLM после транскрибации. Исправляет ошибки распознавания и восстанавливает англицизмы. По умолчанию выключена."
        case .infoInterface:
            return "Язык отображения интерфейса."

        // Hotkeys section
        case .hotkeyPTT:                  return "PTT (удерживать)"
        case .hotkeyVAD:                  return "Вкл/выкл VAD"
        case .hotkeyHint:                 return "Нажмите кнопку → нажмите клавишу (или зажмите модификатор и отпустите). Esc — отмена."
        case .hotkeyReset:                return "Сбросить к значению по умолчанию"
        case .hotkeyPressKey:             return "Нажмите клавишу..."

        // Model section
        case .modelLocal:                 return "Локальная"
        case .modelCloud:                 return "Облако (API)"
        case .modelLoading:               return "загрузка..."
        case .modelActive:                return "Активна"
        case .modelSelect:                return "Выбрать"
        case .modelDownload:              return "Скачать"
        case .modelApiKeyFor:             return "API-ключ для"
        case .modelSave:                  return "Сохранить"
        case .modelKeychainNote:          return "Ключ хранится в Keychain, не покидает устройство."
        case .modelKeySet:                return "ключ задан"

        // Language section
        case .langTitle:                  return "Язык транскрибации"
        case .langHint:                   return "Выберите язык речи. «Авто» работает медленнее, но определяет язык самостоятельно."
        case .langAuto:                   return "Авто (определить)"

        // Prompt section
        case .promptTitle:                return "Промт Whisper"
        case .promptReset:                return "Сбросить"
        case .promptDisabledHint:         return "Включите, чтобы добавить подсказку модели Whisper."
        case .promptDefaultText:          return "Текст может содержать технические термины на английском языке."

        // Correction section
        case .correctionTitle:            return "Коррекция текста"
        case .correctionPromptLabel:      return "ПРОМТ КОРРЕКЦИИ"
        case .correctionPromptReset:      return "Сбросить"
        case .correctionOffDescription:   return "Текст вставляется как есть после транскрибации"
        case .correctionOllamaDescription: return "Локально, без интернета. Добавляет ~1–3 сек, нагружает RAM"
        case .correctionApiDescription:   return "Требует интернет и API-ключ. Быстро, но зависит от сети"
        case .correctionInstallOllama:    return "Установить Ollama"
        case .correctionDownloadModel:    return "Скачать модель"
        case .correctionLoadingModel:     return "Загрузка модели..."
        case .correctionOllamaModelLabel: return "Модель:"
        case .correctionApiKeyLabel:      return "API-ключ"
        case .correctionSave:             return "Сохранить"
        case .correctionKeychainNote:     return "Ключ хранится в Keychain, не покидает устройство."
        case .correctionGroqHint:         return "Groq предоставляет бесплатный тир — groq.com"
        case .correctionOllamaStatusNotInstalled: return "не установлена"
        case .correctionOllamaStatusInstalling:   return "установка..."
        case .correctionOllamaStatusInstallError: return "ошибка установки"
        case .correctionOllamaStatusStopped:      return "остановлен"
        case .correctionOllamaStatusStarting:     return "запускается..."
        case .correctionOllamaStatusStopping:     return "останавливается..."
        case .correctionOllamaStatusServerError:  return "ошибка сервера"
        case .correctionOllamaStatusReady:        return "готово"
        case .correctionOllamaStatusPulling:      return "загрузка модели..."
        case .correctionOllamaStatusNotPulled:    return "модель не скачана"
        case .correctionOllamaStatusModelError:   return "ошибка модели"
        case .correctionModelError:               return "Ошибка модели: "
        case .correctionInstallError:             return "Ошибка установки: "
        case .correctionPromptInfoHint:
            return "Инструкция для LLM. Определяет что именно исправлять. Можно адаптировать под свои нужды."

        // Interface section
        case .interfaceTitle:             return "Интерфейс"
        case .interfaceLanguageLabel:     return "Язык"

        // Overlay
        case .overlayStatusLoading:       return "Загрузка модели..."
        case .overlayStatusRecording:     return "Запись"
        case .overlayStatusVADRecording:  return "VAD · Запись"
        case .overlayStatusTranscribing:  return "Распознавание..."
        case .overlayStatusDone:          return "Готово"
        case .overlayStatusVADListening:  return "VAD · Слушаю"
        case .overlayStatusReady:         return "Готово к записи"
        case .overlayTranscribing:        return "Распознавание..."
        case .overlayCopy:                return "Копировать"
        case .overlayCopied:              return "Скопировано"
        case .overlayInserted:            return "вставлено"
        case .overlayHoldToRecord:        return "Удерживайте %@ для записи"

        // History
        case .historyTitle:               return "История"
        case .historyEmpty:               return "Нет записей"

        // Donate
        case .donateTitle:                return "Поддержать"
        case .donateCaption:              return "Поддержите автора прокормить этого толстяка"
        case .donateCopyAddress:          return "Скопировать адрес"

        // Splash
        case .splashSupport:              return "Поддержать"

        // Menu
        case .menuShow:                   return "Показать"
        case .menuMode:                   return "Режим: PTT / VAD"
        case .menuSettings:               return "Настройки..."
        case .menuQuit:                   return "Выйти"
        }
    }
}
