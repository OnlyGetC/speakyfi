# VoiceToText

Нативное macOS-приложение для голосового ввода текста.

Вдохновлено [SuperWhisper](https://superwhisper.com), написано на Swift/SwiftUI с открытым исходным кодом.

Бесплатная альтернатива SuperWhisper и Spokenly. Локальная транскрибация без подписки — всё на устройстве. Опционально — облачные API и коррекция текста через LLM.

---

## Возможности

- **Push-to-Talk** — удерживайте хоткей для записи, отпустите — текст вставится автоматически
- **VAD-режим** — автоматическое определение речи без нажатия клавиш
- **Выбор модели** — tiny / base / small / medium / large, скачивание и смена на лету
- **Облачные API** — OpenAI Whisper, Groq, Deepgram (API-ключ хранится в Keychain)
- **Коррекция текста** — постобработка через LLM: исправляет ошибки распознавания, восстанавливает англицизмы и термины
- **Транскрибация файлов** — перетащите аудио или видео (mp3, mp4, wav, m4a, mov), получите транскрипцию с таймкодами. Диаризация спикеров через Deepgram API. Экспорт в .txt, .md, .srt
- **История транскрипций** — последние 50 записей с копированием
- **Настраиваемые хоткеи** — любая клавиша или модификатор (⌘ ⌃ ⌥ ⇧)
- **Автовставка** — текст сразу появляется в активном поле любого приложения
- **Меню-бар** — живёт в статус-баре, не засоряет Dock
- **Intel Mac** — поддержка x86_64 через whisper.cpp (whisper.cpp backend, GGML модели)

---

## Требования

- macOS 13.0+
- Apple Silicon (M1 и новее) или Intel Mac (x86_64)
- От ~150 МБ свободного места (зависит от выбранной модели)

---

## Установка

### Готовый архив

Скачайте `VoiceToText-v1.4.zip` из [Releases](https://github.com/OnlyGetC/voice-to-text-swift/releases), распакуйте и перетащите в `/Applications`.

### Сборка из исходников

```bash
git clone https://github.com/OnlyGetC/voice-to-text-swift
cd voice-to-text-swift
swift build -c release

APP=dist/VoiceToText.app
mkdir -p $APP/Contents/MacOS
cp .build/release/VoiceToText $APP/Contents/MacOS/VoiceToText
cp -r .build/arm64-apple-macosx/release/VoiceToText_VoiceToText.bundle $APP/Contents/MacOS/
cp VoiceToText/Resources/Info.plist $APP/Contents/Info.plist
cp -r $APP /Applications/
```

При первом запуске в локальном режиме модель скачается автоматически с HuggingFace.

---

## Разрешения

После установки выдайте разрешения в **Системные настройки → Конфиденциальность и безопасность**:

| Разрешение | Зачем |
|---|---|
| Микрофон | Запись голоса |
| Универсальный доступ | Автовставка текста (Cmd+V) |
| Автоматизация | Активация нужного приложения перед вставкой |

> После каждой пересборки macOS сбрасывает разрешение «Универсальный доступ» — удалите и добавьте VoiceToText заново в списке.

---

## Использование

1. Запустите `VoiceToText.app` — появится иконка 🎙 в меню-баре
2. Поставьте курсор в любое текстовое поле
3. Удерживайте **⌃ Control** (PTT по умолчанию) — говорите
4. Отпустите — текст транскрибируется и вставится автоматически

**Настройки**: меню-бар → Настройки (⌘,)

---

## Настройки — разделы

### Модель

| Режим | Описание |
|---|---|
| Локальная | WhisperKit на устройстве, без интернета |
| Облако (API) | OpenAI Whisper / Groq / Deepgram, нужен API-ключ |

Локальные модели:

| Модель | Размер | Качество |
|---|---|---|
| tiny | ~75 МБ | Низкое, очень быстро |
| base | ~142 МБ | Базовое |
| small | ~466 МБ | Баланс (по умолчанию) |
| medium | ~1.5 ГБ | Высокое |
| large v3 | ~3 ГБ | Максимальное |

### Коррекция текста

Опциональный шаг после транскрибации — LLM исправляет ошибки распознавания и восстанавливает технические термины и англицизмы в оригинальном написании (git, JSON, API, OK и т.д.).

| Режим | Описание |
|---|---|
| Выключено | Текст вставляется как есть (по умолчанию) |
| Локально (Ollama) | Устанавливается прямо из приложения, модель `llama3.2:1b` (~1.3 ГБ), без интернета |
| API | OpenAI, Groq (бесплатный тир), свой эндпоинт |

Промт коррекции редактируется в настройках.

---

## Архитектура

```
VoiceToText/Sources/
├── App/
│   ├── VoiceToTextApp.swift               # @main точка входа
│   ├── AppDelegate.swift                  # меню-бар, оркестрация
│   └── AppState.swift                     # общее состояние (ObservableObject)
├── Features/
│   ├── Recording/
│   │   ├── AudioRecorder.swift            # AVAudioEngine, PTT и VAD
│   │   └── HotkeyManager.swift            # глобальные хоткеи
│   ├── Transcription/
│   │   ├── Transcriber.swift              # WhisperKit, смена модели на лету
│   │   ├── ModelManager.swift             # статус и скачивание локальных моделей
│   │   ├── CloudTranscriber.swift         # OpenAI / Groq / Deepgram API
│   │   ├── TextCorrectionService.swift    # постобработка через LLM
│   │   └── OllamaManager.swift            # установка Ollama, сервер, pull модели
│   └── Output/
│       └── OutputHandler.swift            # CGEvent postToPid — автовставка
└── UI/
    ├── OverlayWindow.swift                # floating NSWindow + KeyableWindow
    ├── OverlayView.swift                  # compact pill оверлей
    ├── WaveformView.swift                 # анимация волны
    ├── SettingsView.swift                 # sidebar: 5 разделов, 700×520px
    ├── HistoryView.swift                  # история транскрипций
    └── DonateView.swift                   # экран поддержки автора
```

---

## Стек

- **Swift 5.9** + **SwiftUI**
- **WhisperKit** — локальная транскрибация на Apple Silicon
- **AVAudioEngine** — запись с микрофона
- **CoreGraphics CGEvent** — автовставка текста (`postToPid`)
- **Security (Keychain)** — хранение API-ключей
- **Ollama** — локальный LLM-сервер для коррекции текста

---

## Changelog

### v1.6.1
- Fixed: File Transcription window now has a close (✕) button — previously the window could only be closed by restarting the app

### v1.6
- Транскрибация аудио/видео-файлов — drag & drop, таймкоды, диаризация спикеров через Deepgram API
- Экспорт транскрипции в .txt, .md, .srt (SubRip с таймкодами)
- Поддержка Intel Mac (x86_64) — whisper.cpp backend, GGML модели скачиваются автоматически

### v1.5
- Локализация интерфейса (English / Русский)
- Проверка обновлений в Settings → Interface

### v1.4
- Коррекция текста через LLM: Ollama (установка из приложения) или API (OpenAI/Groq/свой эндпоинт)
- Редизайн настроек: боковое меню с 5 разделами, окно 700×520px
- Кнопка ⓘ с описанием у каждого раздела
- Исправлено: попап подсказки обрезал текст

### v1.3
- Выбор локальной модели: tiny / base / small / medium / large, скачивание и смена на лету
- Облачные API: OpenAI Whisper, Groq, Deepgram; API-ключ в Keychain
- Экран доната 🪙
- Исправлено: окна не принимали фокус (`KeyableWindow`)
- Исправлено: модели не определялись как скачанные
- Исправлено: ошибка «Model folder is not set» при запуске

### v1.2
- Панель истории транскрипций
- Редизайн оверлея: compact pill, blur-фон, кнопки истории и настроек

### v1.1
- Выбор языка транскрибации (ru, en, auto и др.)
- Подсказка модели (prompt)
- Настраиваемые хоткеи с recorder-кнопкой

### v1.0
- Push-to-Talk и VAD-режим
- Автовставка через CGEvent
- Меню-бар

---

## Roadmap

- [x] Локализация интерфейса (English / Русский) + язык сплэш-фраз по языку системы
- [x] Проверка обновлений в Settings — кнопка «Проверить обновления», сравнение с GitHub Releases API, при наличии новой версии показывает статус + кнопка «Скачать».
- [x] Поддержка Intel Mac (whisper.cpp)
- [ ] Поддержка Windows
- [x] Автозапуск при входе в систему — не нужен
- [x] ★ Транскрибация аудио/видео-файлов — таймкоды, диаризация через Deepgram API, экспорт .txt / .md / .srt

---

## Лицензия

MIT
