# VoiceToText

Нативное macOS-приложение для голосового ввода текста. Нажми хоткей — скажи — текст появится там, где стоит курсор.

Вдохновлено [SuperWhisper](https://superwhisper.com), написано на Swift/SwiftUI с открытым исходным кодом.

Бесплатная альтернатива SuperWhisper и Spokenly. Все локально и без подключения к интернету, нужен только при первом запуске для загрузки модели транскрибации.

---

## Возможности

- **Push-to-Talk** — удерживайте хоткей для записи, отпустите — текст вставится автоматически
- **VAD-режим** — автоматическое определение речи без нажатия клавиш
- **Локальная транскрибация** — модель работает на устройстве через [WhisperKit](https://github.com/argmaxinc/WhisperKit), данные никуда не уходят
- **Настраиваемые хоткеи** — любая клавиша или модификатор (⌘, ⌃, ⌥, ⇧ + клавиша, или только модификатор)
- **Автовставка** — текст сразу появляется в активном поле любого приложения
- **Меню-бар** — приложение живёт в статус-баре, не засоряет Dock

---

## Требования

- macOS 13.0+
- Apple Silicon (M1 и новее)
- ~600 МБ свободного места (модель Whisper Small)

---

## Установка

```bash
git clone https://github.com/OnlyGetC/voice-to-text-swift
cd voice-to-text-swift
swift build -c release
```

Собрать `.app`:
```bash
APP=dist/VoiceToText.app
mkdir -p $APP/Contents/MacOS
cp .build/release/VoiceToText $APP/Contents/MacOS/VoiceToText
cp Resources/Info.plist $APP/Contents/Info.plist   # или скопируйте вручную
cp -r $APP /Applications/
```

При первом запуске модель `whisper-small` (~500 МБ) скачается автоматически с HuggingFace.

---

## Разрешения

После установки выдайте разрешения в **Системные настройки → Конфиденциальность и безопасность**:

| Разрешение | Зачем |
|---|---|
| Микрофон | Запись голоса |
| Универсальный доступ | Автовставка текста (Cmd+V) |
| Автоматизация | Активация нужного приложения перед вставкой |

---

## Использование

1. Запустите `VoiceToText.app` — появится иконка 🎙 в меню-баре
2. Поставьте курсор в любое текстовое поле
3. Удерживайте **⌃ Control** (хоткей по умолчанию) — говорите
4. Отпустите — текст транскрибируется и вставится автоматически

**Настройка хоткеев**: меню-бар → Настройки (⌘,)

---

## Архитектура

```
VoiceToText/Sources/
├── App/
│   ├── VoiceToTextApp.swift     # @main точка входа
│   ├── AppDelegate.swift        # меню-бар, оркестрация
│   └── AppState.swift           # общее состояние (ObservableObject)
├── Features/
│   ├── Recording/
│   │   ├── AudioRecorder.swift  # AVAudioEngine, PTT и VAD
│   │   └── HotkeyManager.swift  # глобальные хоткеи
│   ├── Transcription/
│   │   └── Transcriber.swift    # WhisperKit обёртка
│   └── Output/
│       └── OutputHandler.swift  # буфер обмена + CGEvent Cmd+V
└── UI/
    ├── OverlayWindow.swift      # floating NSWindow
    ├── OverlayView.swift        # SwiftUI интерфейс
    ├── WaveformView.swift       # анимация волны
    └── SettingsView.swift       # настройки хоткеев
```

---

## Roadmap

### v1.1
- [ ] Выбор языка транскрибации из настроек (ru, en, auto и другие)
- [ ] История транскрипций с возможностью копирования
- [ ] Уведомление об успешной вставке

### v1.2
- [ ] Дополнительные модели Whisper — `tiny`, `base`, `medium`, `large` на выбор
- [ ] Поддержка сторонних моделей через OpenAI-совместимый API (Ollama, LM Studio)
- [ ] Пунктуация и форматирование через LLM после транскрибации

### v1.3
- [ ] Поддержка Intel Mac (замена WhisperKit на whisper.cpp)
- [ ] Автозапуск при входе в систему
- [ ] Глобальная история с поиском

### v2.0
- [ ] Поддержка Windows (на базе whisper.cpp + Tauri или Electron)
- [ ] Облачные модели — OpenAI Whisper API, Groq Whisper как опция
- [ ] Плагины для популярных приложений (Obsidian, Notion, VS Code)
- [ ] Многоязычный режим — автоопределение языка без потери качества

---

## Стек

- **Swift 5.9** + **SwiftUI**
- **WhisperKit** — локальная транскрибация на Apple Silicon
- **AVAudioEngine** — запись с микрофона
- **CoreGraphics CGEvent** — автовставка текста

---

## Лицензия

MIT
