# Review: T-004 File Transcription

**Reviewer:** review-agent
**Date:** 2026-06-06

## Result: PASS WITH NOTES

---

## Issues found

### MINOR — Copy button copies `fullText`, ignores selected export format

**File:** `FileTranscriptionView.swift`, line 484

```swift
private func copyToClipboard(_ result: FileTranscriptionResult) {
    let text = result.fullText
    ...
}
```

`fullText` is a plain joined string with no speaker labels, no timestamps, no formatting. A user who selects "SRT" or "MD" format and clicks "Copy" reasonably expects formatted output matching their selection. The correct call is `TranscriptionExporter.format(result, as: exportFormat)`, which is already available as a pure function.

This is a functional gap — Copy and Export produce inconsistent output when the format is not TXT.

---

### MINOR — `showFileTranscriptionWindow` does not guard `isVisible` on reopen with the same strictness as `historyWindow`

**File:** `AppDelegate.swift`, lines 136–161

`historyWindow` guards with `existing.isVisible` — same pattern is used correctly in `showFileTranscription`. No actual issue, noted as confirmed correct.

---

### NOTE — `Data(contentsOf:)` loads entire file into memory

**File:** `FileTranscriber.swift`, line 178

```swift
let fileData = try Data(contentsOf: fileURL)
```

For large video files (e.g. 2 GB `.mov` or `.mp4`) this will load the entire file into RAM before the upload begins. Deepgram supports chunked/streaming uploads via `URLSession.uploadTask(withStreamedRequest:)`, which would avoid the memory spike. For typical audio files (MP3, M4A, WAV) this is acceptable. Flag as a scalability note — not a blocking issue given the current intended use case.

---

### NOTE — `httpError` case leaks full Deepgram response body into user-visible error

**File:** `FileTranscriber.swift`, lines 29, 209–210

```swift
case .httpError(let code, let body):
    return "Deepgram HTTP \(code): \(body)"
```

The response body is displayed to the user. Deepgram error responses typically contain only status info, not the API key. However, in edge cases (e.g. a misconfigured proxy or non-standard error format) the body could contain sensitive data. The API key itself is sent in the `Authorization` header only, so it will not appear in the body. Risk is low — noted as a defensive concern.

---

### NOTE — Intel path (`transcribeLocalWhisperCpp`) references `WhisperCppBackend` without an import

**File:** `FileTranscriber.swift`, lines 140–146

The `#else` branch calls `WhisperCppBackend()` and `backend.loadModel(.base)` / `backend.transcribe(...)`. There is no `import` statement for this type visible in the file. It must be defined in the same module. This is acceptable if `WhisperCppBackend` is part of the app target, but worth verifying at build time on x86_64.

---

## Notes (checklist results)

**FileTranscriber.swift**
- [x] `#if arch(arm64)` guard around `import WhisperKit` — correct, lines 3–5
- [x] Intel path `#else` compiles without WhisperKit — uses `WhisperCppBackend` + `AVFoundation`
- [x] Deepgram key lookup uses Keychain (`KeychainHelper.load(key: CloudProvider.deepgram.keychainKey)`) — matches pattern
- [x] MIME type mapping covers all 5 formats: mp3, mp4, wav, m4a, mov — confirmed lines 237–244
- [x] Error cases are `LocalizedError` with useful messages — confirmed
- [x] `progress` and `status` updated throughout both paths — confirmed
- [x] Deepgram: `language != "auto"` check before appending query param — correct, line 191

**TranscriptionExporter.swift**
- [x] SRT timecode uses comma as decimal separator — `%02d:%02d:%02d,%03d` confirmed line 172
- [x] MD speaker grouping: consecutive same-speaker segments are merged — confirmed `formatMdWithSpeakers`, lines 107–128
- [x] TXT with no speakers: wrapped at ~80 chars on sentence boundaries — confirmed lines 73–94
- [x] `NSSavePanel` called inside `@MainActor` function — confirmed, `export` is `@MainActor`, line 30
- [x] `format(_:as:)` is pure — no side effects, confirmed

**FileTranscriptionView.swift**
- [x] Three view states work logically: `.empty` → `.processing` → `.result`
- [x] Drag & drop filters to allowed extensions only — `allowedExtensions` check in `handleDrop`, line 429
- [x] Cancel button cancels the async Task — `transcriptionTask?.cancel()` line 471
- [~] Copy button copies to `NSPasteboard` — yes, but copies `fullText` regardless of selected format (see Issue 1)
- [x] Export calls `TranscriptionExporter.export()` correctly — line 492
- [x] "New File" button resets state cleanly — `result`, `droppedFileURL`, `fileName` all cleared, line 476–481

**AppDelegate.swift / OverlayView.swift / OverlayWindow.swift**
- [x] `fileTranscriptionWindow` follows same pattern as `historyWindow` — confirmed
- [x] Menu item added with `@objc` selector `showFileTranscriptionAction` — line 37, 163
- [x] `onFileTranscription` wired: `AppDelegate.setupOverlayWindow` → `OverlayWindow.init` → `OverlayView` property — fully confirmed

**Security**
- [x] API key not logged — only used in `Authorization` header, not in any status or error string
- [x] `Data(contentsOf:)` noted — acceptable for current use case, memory concern flagged above

---

## Verdict

The implementation is functionally correct and well-structured. All checklist items pass. One functional gap was found: the Copy button ignores the selected export format and always copies plain text. This should be fixed before release but does not block testing. The memory concern with `Data(contentsOf:)` is acceptable for the stated supported formats. The `WhisperCppBackend` reference on Intel should be verified at build time.

**Result: PASS WITH NOTES**
