# Review: T-003 Intel Mac support

**Reviewer:** review-agent
**Date:** 2026-06-06

## Result: PASS WITH NOTES

---

## Issues found

### 1. [MINOR / RISK] `refreshDownloadedStatus()` on Intel always resets all models to `notDownloaded`

**File:** `ModelManager.swift`, lines 149–154

The Intel branch of `refreshDownloadedStatus()` sets every model to `.notDownloaded` unconditionally (skipping only those actively `.downloading`). It does NOT check the filesystem via `isIntelModelDownloaded(_:)` the way the arm64 branch checks for `.mlmodelc` files.

This means: on every app launch, all models will appear as "not downloaded" in the UI even if the `.bin` files are already present on disk. The user would see no downloaded models and potentially try to re-download them.

`isIntelModelDownloaded(_:)` exists and correctly checks the filesystem, but it is never called from `refreshDownloadedStatus()`.

**Verdict:** Not a crash, but incorrect UI behavior on Intel at every app launch. Should be fixed before shipping.

---

### 2. [MINOR] 16 kHz mono audio requirement is not documented or enforced

**File:** `WhisperCppBackend.swift`, `transcribe(audio:language:prompt:)`

SwiftWhisper/whisper.cpp requires audio input to be 16 kHz, mono, 32-bit float PCM. `WhisperCppBackend` passes the `[Float]` array directly to `whisper.transcribe(audioFrames:)` with no assertion, comment, or enforcement that the caller has already resampled/converted the audio. If the calling code passes audio at a different sample rate, the transcription result will be silently wrong (no crash, no error).

**Verdict:** Not a crash risk by itself, but a correctness risk if the audio pipeline is ever changed. A comment at minimum is required.

---

### 3. [LOW] Force-unwrap in `modelsDirectory` (both arm64 and Intel paths)

**Files:** `ModelManager.swift` line 96, `WhisperCppBackend.swift` line 10

Both use:
```swift
FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
```

On macOS sandboxed apps this always succeeds, so the force-unwrap is practically safe. However it is a code quality issue — a future sandbox configuration change could cause a crash here.

**Verdict:** Acceptable for a pet project; worth noting.

---

### 4. [LOW] `downloadModel(_:onProgress:)` on Intel is a no-op stub

**File:** `ModelManager.swift`, lines 160–162

The Intel implementation of `downloadModel` does nothing. Download is performed transparently inside `WhisperCppBackend.loadModel`. This means the `ModelManager.modelStatuses` dictionary is never updated to `.downloading` or `.downloaded` during an actual download initiated from the UI through `ModelManager`. The status only updates if the UI calls `WhisperCppBackend` directly.

This is architecturally inconsistent: on arm64 the `ModelManager` owns the download and tracks status; on Intel the `WhisperCppBackend` owns the download and `ModelManager` tracks nothing. If any UI component calls `ModelManager.downloadModel` on Intel, the user gets no feedback and no download occurs.

**Verdict:** Architectural inconsistency. Not a crash, but a behavioral gap that will surface as a UI bug if `downloadModel` is wired to a UI button on Intel.

---

## Notes

- `#if arch(arm64)` / `#if !arch(arm64)` guards are consistent and non-overlapping across all four files. No overlap or missing branch found.
- `import SwiftWhisper` is correctly inside `#if !arch(arm64)` (WhisperCppBackend.swift line 3). It will not be imported on Apple Silicon.
- `import WhisperKit` is correctly inside `#if arch(arm64)` in both `Transcriber.swift` (line 4) and `ModelManager.swift` (line 3). It will not be imported on Intel.
- Both `Transcriber` implementations expose the same public interface: `loadModel`, `switchModel(to:)`, `transcribe(audio:language:prompt:)`. Interface parity is confirmed.
- `WhisperCppBackend.transcribe` correctly calls `whisper.transcribe(audioFrames:)` and joins segment texts with `map { $0.text }.joined(separator: " ")`. This matches the arm64 pattern.
- Atomic write in `downloadModel`: temp file (`destination.appendingPathExtension("tmp")`) is written first, then moved to destination via `FileManager.moveItem`. A `defer` block cleans up the temp file on any exit path. Pattern is correct.
- HuggingFace download URL: `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-<name>.bin` — correct.
- `Package.swift` uses `branch: "master"` for SwiftWhisper — correct as required.
- `LocalWhisperModel.large` maps to `IntelWhisperModel.medium` (line 91 of Transcriber.swift) — acceptable fallback, consistent with the checklist.
- No memory leaks detected: `whisper = Whisper(fromFileURL:)` in `loadModel` replaces the old instance directly; ARC handles deallocation.
- Network errors in `downloadModel` are handled: HTTP status is checked, a `catch` block reports the error via `onProgress`. No silent failure.
- `FileManager.default.createDirectory` failure is silently ignored via `try?` — acceptable here since the subsequent file write will also fail and that error is caught.

---

## Verdict

The implementation is structurally sound. All conditional compilation guards are correct, both backend paths compile independently, and the core transcription logic is correct. Two behavioral issues prevent a clean PASS:

1. Intel `refreshDownloadedStatus()` does not check the filesystem — models always appear as not downloaded on launch.
2. Intel `ModelManager.downloadModel` is a no-op stub — download initiated through `ModelManager` silently does nothing on Intel.

Both are correctness/UX bugs, not crash-level bugs. Result: **PASS WITH NOTES**.
