# VoiceToText

Нативное macOS-приложение для голосового ввода текста.

Вдохновлено [SuperWhisper](https://superwhisper.com), написано на Swift/SwiftUI с открытым исходным кодом.

Бесплатная альтернатива SuperWhisper и Spokenly. Локальная транскрибация без подписки — всё на устройстве. Опционально — облачные API (OpenAI, Groq, Deepgram).

---

## Возможности

- **Push-to-Talk** — удерживайте хоткей для записи, отпустите — текст вставится автоматически
- **VAD-режим** — автоматическое определение речи без нажатия клавиш
- **Выбор модели** — tiny / base / small / medium / large, скачивание и смена на лету
- **Облачные API** — OpenAI Whisper, Groq, Deepgram (API-ключ хранится в Keychain)
- **История транскрипций** — последние 50 записей с копированием
- **Настраиваемые хоткеи** — любая клавиша или модификатор (⌘ ⌃ ⌥ ⇧)
- **Автовставка** — текст сразу появляется в активном поле любого приложения
- **Меню-бар** — живёт в статус-баре, не засоряет Dock

---

## Требования

- macOS 13.0+
- Apple Silicon (M1 и новее)
- От ~150 МБ свободного места (зависит от выбранной модели)

---

## Установка

### Готовый архив

Скачайте `VoiceToText-v1.3.zip` из [Releases](https://github.com/OnlyGetC/voice-to-text-swift/releases), распакуйте и перетащите в `/Applications`.

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

## Выбор модели

В Настройках → секция **МОДЕЛЬ**:

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

---

## Архитектура

```
VoiceToText/Sources/
├── App/
│   ├── VoiceToTextApp.swift          # @main точка входа
│   ├── AppDelegate.swift             # меню-бар, оркестрация
│   └── AppState.swift                # общее состояние (ObservableObject)
├── Features/
│   ├── Recording/
│   │   ├── AudioRecorder.swift       # AVAudioEngine, PTT и VAD
│   │   └── HotkeyManager.swift       # глобальные хоткеи
│   ├── Transcription/
│   │   ├── Transcriber.swift         # WhisperKit, смена модели на лету
│   │   ├── ModelManager.swift        # статус и скачивание локальных моделей
│   │   └── CloudTranscriber.swift    # OpenAI / Groq / Deepgram API
│   └── Output/
│       └── OutputHandler.swift       # CGEvent postToPid — автовставка
└── UI/
    ├── OverlayWindow.swift           # floating NSWindow + KeyableWindow
    ├── OverlayView.swift             # compact pill оверлей
    ├── WaveformView.swift            # анимация волны
    ├── SettingsView.swift            # настройки, выбор модели
    ├── HistoryView.swift             # история транскрипций
    └── DonateView.swift              # экран поддержки автора
```

---

## Стек

- **Swift 5.9** + **SwiftUI**
- **WhisperKit** — локальная транскрибация на Apple Silicon
- **AVAudioEngine** — запись с микрофона
- **CoreGraphics CGEvent** — автовставка текста (`postToPid`)
- **Security (Keychain)** — хранение API-ключей

---

## Changelog

### v1.3
- Выбор локальной модели: tiny / base / small / medium / large, скачивание и смена на лету
- Облачные API: OpenAI Whisper, Groq, Deepgram; API-ключ в Keychain
- Экран доната 🪙
- Исправлено: окна настроек/истории/доната не принимали фокус (`KeyableWindow`)
- Исправлено: модели не определялись как скачанные (неверный путь и префикс имён)
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

- [ ] Поддержка Intel Mac (whisper.cpp)
- [ ] Автозапуск при входе в систему
- [ ] Пунктуация и форматирование через LLM после транскрибации
- [ ] Поддержка Windows

---

## Лицензия

MIT
