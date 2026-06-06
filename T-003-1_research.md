# Research: whisper.cpp Swift SPM integration

**Task:** T-003-1
**Date:** 2026-06-06

## Summary

The recommended approach for adding whisper.cpp support to a Swift/SPM project on both Intel and Apple Silicon Macs is to use **exPHAT/SwiftWhisper** — a Swift wrapper around whisper.cpp that works on both architectures via CPU inference. The official ggerganov/whisper.spm repository is archived and no longer maintained. The main pain point is that packages using whisper.cpp include unsafe build flags, which forces dependency specification via branch or commit hash instead of a semver tag. Architecture detection at runtime is straightforward using `sysctlbyname` or `#if arch()` at compile time, allowing clean conditional use of WhisperKit (Apple Silicon) vs SwiftWhisper (Intel).

## Key findings

### 1. Best SPM package

**Option A — exPHAT/SwiftWhisper (recommended)**

- GitHub: https://github.com/exPHAT/SwiftWhisper
- Latest version: `1.2.0` (August 17, 2024), but must be referenced via branch due to unsafe flags
- Wraps whisper.cpp directly, supports macOS and iOS, works on Intel and Apple Silicon
- Bundles whisper.cpp as a submodule, so no separate C library install needed
- Enables `GGML_USE_ACCELERATE` and optional CoreML acceleration via build flags

Add to `Package.swift`:
```swift
// IMPORTANT: Must use branch, not version — unsafe build flags prevent semver resolution
.package(url: "https://github.com/exPHAT/SwiftWhisper.git", branch: "master")
```

And in target dependencies:
```swift
.target(
    name: "VoiceToText",
    dependencies: [
        .product(name: "WhisperKit", package: "WhisperKit"),
        .byName(name: "SwiftWhisper"),   // for Intel
    ]
)
```

**Option B — ggerganov/whisper.spm (archived, do not use)**

- GitHub: https://github.com/ggerganov/whisper.spm
- Status: **Archived and no longer maintained** as of 2024. The README explicitly instructs users to migrate to the Swift package in the main whisper.cpp repo.
- Not viable for new projects.

**Option C — ggml-org/whisper.cpp direct Swift binding**

- The main repo (https://github.com/ggml-org/whisper.cpp) has a Swift package manifest, but it also uses unsafe build flags and is complex to integrate without the wrapper.
- SwiftWhisper is a cleaner consumer of this.

### 2. Swift API example

SwiftWhisper accepts a `[Float]` array of 16 kHz mono PCM audio frames — matching Speakyfi's existing interface.

```swift
import SwiftWhisper

// Load model from a local .bin file URL
let modelURL = URL(fileURLWithPath: "/path/to/ggml-base.bin")
let whisper = Whisper(fromFileURL: modelURL)

// transcribe() takes [Float] of 16 kHz mono PCM, returns [Segment]
func transcribeWithWhisperCPP(_ audioFrames: [Float]) async throws -> String? {
    let segments = try await whisper.transcribe(audioFrames: audioFrames)
    let text = segments.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    return text.isEmpty ? nil : text
}
```

Integration pattern in the existing Transcriber.swift (keeping WhisperKit for Apple Silicon):

```swift
import Foundation
#if arch(arm64)
import WhisperKit
#else
import SwiftWhisper
#endif

class Transcriber {
    func transcribe(audio: [Float]) async -> String? {
#if arch(arm64)
        // Existing WhisperKit path
        return await transcribeWithWhisperKit(audio)
#else
        // New whisper.cpp path for Intel
        return try? await transcribeWithWhisperCPP(audio)
#endif
    }
}
```

Alternatively, for runtime detection (e.g., if the binary is a universal/fat binary):

```swift
import Darwin

func isAppleSilicon() -> Bool {
    var sysctl_value: Int32 = 0
    var len = MemoryLayout<Int32>.size
    let result = sysctlbyname("hw.optional.arm64", &sysctl_value, &len, nil, 0)
    return result == 0 && sysctl_value == 1
}
```

### 3. GGUF model downloads

whisper.cpp uses its own GGML binary format (`.bin` files), not the GGUF format used by llama.cpp. All official models are hosted at:

**https://huggingface.co/ggerganov/whisper.cpp**

Model names and approximate sizes:

| Model | File name | Size |
|---|---|---|
| tiny | `ggml-tiny.bin` | 77.7 MB |
| tiny (English only) | `ggml-tiny.en.bin` | 77.7 MB |
| tiny quantized | `ggml-tiny-q5_1.bin` | 32.2 MB |
| base | `ggml-base.bin` | 148 MB |
| base (English only) | `ggml-base.en.bin` | 148 MB |
| small | `ggml-small.bin` | 488 MB |
| small (English only) | `ggml-small.en.bin` | 488 MB |
| medium | `ggml-medium.bin` | 1.53 GB |
| large-v3 | `ggml-large-v3.bin` | 3.1 GB |
| large-v3-turbo | `ggml-large-v3-turbo.bin` | 1.62 GB |
| large-v3-turbo quantized | `ggml-large-v3-turbo-q5_0.bin` | 574 MB |

For Intel Macs, `ggml-base.bin` or `ggml-small.bin` are practical choices. The quantized variants (`-q5_1`, `-q8_0`) offer smaller size with minimal quality loss.

Direct download URL pattern:
```
https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
```

### 4. Architecture detection in Swift

**Compile-time (recommended for static dispatch):**

```swift
#if arch(arm64)
// Apple Silicon — use WhisperKit
#elseif arch(x86_64)
// Intel — use whisper.cpp / SwiftWhisper
#endif
```

This is the cleanest approach and has zero runtime overhead. Note: if Speakyfi distributes a universal binary, both code paths will be compiled into the binary and the correct one selected at compile time per slice. If you ship separate arm64 and x86_64 binaries, `#if arch()` is sufficient.

**Runtime detection (for universal/fat binaries where you cannot use compile-time):**

```swift
import Darwin

func isAppleSilicon() -> Bool {
    var value: Int32 = 0
    var size = MemoryLayout<Int32>.size
    let result = sysctlbyname("hw.optional.arm64", &value, &size, nil, 0)
    return result == 0 && value == 1
}
```

**ProcessInfo does not expose CPU architecture directly** — `sysctlbyname` or `#if arch()` are the correct approaches.

Note: `#if arch(arm64)` will match Apple Silicon Macs running a native arm64 binary. A binary compiled for x86_64 running under Rosetta 2 will match `arch(x86_64)`. To distinguish native vs Rosetta at runtime, use `sysctl hw.optional.arm64` (returns 1 on Apple Silicon hardware regardless of binary slice).

### 5. Known issues and gotchas

1. **Unsafe build flags block semver dependency resolution.** whisper.cpp and packages that wrap it (including SwiftWhisper) use `-O3`, `-fno-objc-arc`, `-Wno-shorten-64-to-32`, and `-DNDEBUG` as unsafe flags. SPM refuses to resolve packages with unsafe flags by version tag. You must use `.branch("master")` or `.revision("COMMIT_HASH")`. This is the single most important gotcha — using `from: "1.2.0"` will fail with a cryptic SPM error.

2. **ggerganov/whisper.spm is archived.** Do not start new integrations against it. Redirect all references to the main whisper.cpp repo or SwiftWhisper.

3. **Performance regression on Intel (whisper.cpp > 1.5.0).** There is a known 2-4x slowdown on Intel Macs introduced around commit b050283. For latency-sensitive use, benchmark with different model sizes and consider using quantized models (e.g., `ggml-base-q5_1.bin`).

4. **No Metal GPU acceleration on Intel Macs.** Metal acceleration in whisper.cpp requires Apple Silicon. On Intel, only the Accelerate framework (via `GGML_USE_ACCELERATE`) and optionally AVX/AVX2 SIMD are used. Expect CPU-only inference.

5. **Audio must be 16 kHz mono Float32.** SwiftWhisper's `transcribe(audioFrames:)` expects `[Float]` at exactly 16000 samples/second, single channel. If Speakyfi's existing audio pipeline produces a different sample rate, a resampling step is required.

6. **Model file must be bundled or downloaded at runtime.** The `.bin` file is not included in the Swift package — it must be downloaded separately and either bundled in the app bundle or downloaded on first run. For Intel fallback, `ggml-base.bin` (148 MB) is a reasonable default.

7. **Compile times are long.** whisper.cpp is a large C++ codebase. Expect significantly longer build times than WhisperKit (which ships pre-compiled binaries). The `fast` branch of SwiftWhisper uses `-O3` to compensate for slow Debug builds.

8. **No async/await in the underlying C API.** SwiftWhisper wraps the synchronous C API with `async/await` via a background thread. Heavy transcription calls will block the thread pool — ensure they are called from a non-critical context.

## Sources

- [GitHub - exPHAT/SwiftWhisper](https://github.com/exPHAT/SwiftWhisper)
- [GitHub - ggerganov/whisper.spm (archived)](https://github.com/ggerganov/whisper.spm)
- [GitHub - ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp)
- [SPM unsafe build flags issue #2149](https://github.com/ggml-org/whisper.cpp/issues/2149)
- [Performance regression on Intel issue #1581](https://github.com/ggml-org/whisper.cpp/issues/1581)
- [Hugging Face — ggerganov/whisper.cpp models](https://huggingface.co/ggerganov/whisper.cpp/tree/main)
- [Apple Developer Forums — detect Apple Silicon](https://developer.apple.com/forums/thread/652667)
- [SwiftWhisper releases](https://github.com/exPHAT/SwiftWhisper/releases/tag/1.2.0)
- [whisper.cpp Objective-C / Swift discussion #313](https://github.com/ggml-org/whisper.cpp/discussions/313)

## Limitations

The following could not be verified without actually building the project:

- Whether SwiftWhisper 1.2.0 on `branch: "master"` compiles cleanly against Swift 5.9 / Xcode 15+ without manual flag adjustments.
- Exact performance numbers for whisper.cpp on Intel Macs with different model sizes — benchmarking required.
- Whether the `#if arch(arm64)` conditional correctly prevents WhisperKit from being linked on Intel when both packages are listed as dependencies (need to verify SPM handles this at link time, not just at the call site).
- Whether the model file format changed between the version of whisper.cpp bundled in SwiftWhisper master and the models available on Hugging Face — if SwiftWhisper pulls an old submodule version, there could be format incompatibilities with newer model files.
- Rosetta 2 behavior: if a user runs the arm64 binary slice on Apple Silicon (normal), or the x86_64 slice under Rosetta, the `#if arch()` detection will still route correctly, but runtime performance under Rosetta would be poor. This edge case should be handled by shipping separate binaries or a universal binary with proper slice selection.
