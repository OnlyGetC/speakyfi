# Research: Deepgram diarization + WhisperKit segments

**Task:** T-004-1
**Date:** 2026-06-06

---

## Summary

Deepgram provides a straightforward REST API for pre-recorded audio transcription with speaker diarization via a single POST to `https://api.deepgram.com/v1/listen`. Files can be sent as raw binary (preferred for local files) or via URL. The `diarize=true` and `utterances=true` query parameters activate speaker labels and segmentation. Nova-2 and Nova-3 both support diarization; Nova-3 is the current recommended model.

WhisperKit's `TranscriptionResult` exposes a `segments: [TranscriptionSegment]` array where each segment has `start: Float`, `end: Float`, and `text: String` in seconds. There is also optional per-word timing via `words: [WordTiming]?`.

---

## Deepgram API

### Endpoint and auth

```
POST https://api.deepgram.com/v1/listen
Authorization: Token YOUR_DEEPGRAM_API_KEY
```

Authentication is a Bearer-style token in the `Authorization` header — same pattern used in `CloudTranscriber.swift` for other providers.

### Request format

Two modes:

**1. Local file upload (binary — recommended for Speakyfi)**

Send the raw audio/video bytes as the request body. Set `Content-Type` to the file's MIME type.

```bash
curl -X POST "https://api.deepgram.com/v1/listen?model=nova-2&diarize=true&utterances=true&punctuate=true" \
  -H "Authorization: Token YOUR_DEEPGRAM_API_KEY" \
  -H "Content-Type: audio/mp4" \
  --data-binary @/path/to/file.mp4
```

**2. Remote URL**

Send a JSON body with a `url` field. Content-Type is `application/json`.

```bash
curl -X POST "https://api.deepgram.com/v1/listen?model=nova-2&diarize=true&utterances=true" \
  -H "Authorization: Token YOUR_DEEPGRAM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/audio.mp3"}'
```

### Key query parameters

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `model` | `nova-2` or `nova-3` | Model selection (both support diarization) |
| `diarize` | `true` | Enable speaker diarization — adds `speaker` int to each word/utterance |
| `utterances` | `true` | Return semantically grouped utterances with speaker labels |
| `punctuate` | `true` | Add punctuation |
| `smart_format` | `true` | Apply smart formatting (numbers, dates, etc.) |
| `language` | `en`, `ru`, etc. | Language code (or omit for auto-detect) |

### Response structure (with example JSON)

The top-level response contains `results.channels[].alternatives[]` (raw word-level data) and `results.utterances[]` (speaker-segmented chunks). For diarization, `utterances` is the primary structure:

```json
{
  "metadata": {
    "request_id": "abc123",
    "model_info": { "name": "nova-2", "version": "2024-01-18.26916" },
    "duration": 45.3
  },
  "results": {
    "channels": [
      {
        "alternatives": [
          {
            "transcript": "Life moves pretty fast. You don't stop and look around.",
            "confidence": 0.9994,
            "words": [
              {
                "word": "Life",
                "start": 10.07,
                "end": 10.31,
                "confidence": 0.999,
                "speaker": 0,
                "speaker_confidence": 0.98
              },
              {
                "word": "moves",
                "start": 10.31,
                "end": 10.63,
                "confidence": 0.9997,
                "speaker": 0,
                "speaker_confidence": 0.97
              }
            ]
          }
        ]
      }
    ],
    "utterances": [
      {
        "id": "35404fd9-12ed-4b58-a9a9-9eaf93475ef6",
        "start": 10.07,
        "end": 11.67,
        "confidence": 0.9994,
        "channel": 0,
        "transcript": "Life moves pretty fast.",
        "speaker": 0,
        "words": [
          {
            "word": "Life",
            "start": 10.07,
            "end": 10.31,
            "confidence": 0.999,
            "speaker": 0
          },
          {
            "word": "moves",
            "start": 10.31,
            "end": 10.63,
            "confidence": 0.9997,
            "speaker": 0
          }
        ]
      },
      {
        "id": "7f9ac310-...",
        "start": 12.10,
        "end": 15.44,
        "confidence": 0.9981,
        "channel": 0,
        "transcript": "You don't stop and look around.",
        "speaker": 1,
        "words": [...]
      }
    ]
  }
}
```

Key fields:
- `utterances[].speaker` — integer speaker ID (0, 1, 2...)
- `utterances[].start` / `.end` — timestamps in seconds (Float)
- `utterances[].transcript` — text of the utterance
- `utterances[].words[].speaker` — per-word speaker label
- `channels[].alternatives[].words[].start` / `.end` — word-level timestamps even without `utterances=true`

### Supported formats

Deepgram supports 100+ audio and video formats. Confirmed formats relevant to Speakyfi:

| Format | Supported |
|--------|-----------|
| MP3 | Yes |
| MP4 | Yes (video — audio track extracted) |
| WAV | Yes |
| M4A | Yes |
| MOV | Yes (QuickTime video) |
| AAC | Yes |
| FLAC | Yes |
| OGG / Opus | Yes |
| WebM | Yes |

For local binary upload, set `Content-Type` appropriately:
- MP3: `audio/mpeg`
- MP4/MOV: `video/mp4` or `video/quicktime`
- WAV: `audio/wav`
- M4A: `audio/mp4`

### Pricing

- **Free tier**: $200 credit on signup, no expiration, no credit card required. Equivalent to ~43,000 minutes (~700 hours) of Nova-2 transcription.
- **Pay-as-you-go** (after credit exhausted):
  - Nova-2: ~$0.0058/min ($0.35/hr)
  - Nova-3: $0.0077/min ($0.46/hr)
- Billing is per-second (no rounding up).
- Diarization does not cost extra — included in the base transcription rate.

---

## WhisperKit segments

### TranscriptionResult structure

`TranscriptionResult` is a reference type (class). Its key fields:

```swift
open class TranscriptionResult: Codable, @unchecked Sendable {
    public var text: String          // Full concatenated transcript
    public var segments: [TranscriptionSegment]
    public var language: String
    public var timings: TranscriptionTimings
    public var seekTime: Float?
}

public struct TranscriptionSegment: Hashable, Codable, Sendable {
    public var id: Int
    public var seek: Int
    public var start: Float          // Segment start time in seconds
    public var end: Float            // Segment end time in seconds
    public var text: String          // Segment text
    public var tokens: [Int]
    public var tokenLogProbs: [[Int: Float]]
    public var temperature: Float
    public var avgLogprob: Float
    public var compressionRatio: Float
    public var noSpeechProb: Float
    public var words: [WordTiming]?  // Optional per-word timing (when enabled)

    public var duration: Float { return end - start }
}

// WordTiming (when word timestamps are enabled via DecodingOptions)
public struct WordTiming {
    public var word: String
    public var tokens: [Int]
    public var start: Float          // Word start in seconds
    public var end: Float            // Word end in seconds
    public var probability: Float
    public var duration: Float { get }
}
```

Note: Whisper works in 30-second chunks internally. Segment `id` reflects which 30s window the segment belongs to (id 0 = 0-30s, id 1 = 30-60s, etc.). The `start`/`end` values are absolute times, not relative to the chunk.

### Swift code example with timestamps

```swift
import WhisperKit

// Basic transcription with segments
func transcribeWithSegments(audioPath: String) async throws -> [TranscriptionSegment] {
    let whisperKit = try await WhisperKit()

    // Optional: enable word-level timestamps
    let options = DecodingOptions(
        skipSpecialTokens: true,
        wordTimestamps: true   // enables words: [WordTiming]? on each segment
    )

    // transcribe returns [TranscriptionResult]
    let results = try await whisperKit.transcribe(
        audioPath: audioPath,
        decodeOptions: options
    )

    // Collect all segments from all results
    let allSegments = results.flatMap { $0.segments }
    return allSegments
}

// Iterate with timestamps
func printSegments(_ segments: [TranscriptionSegment]) {
    for segment in segments {
        let startStr = String(format: "%.2f", segment.start)
        let endStr   = String(format: "%.2f", segment.end)
        print("[\(startStr)s --> \(endStr)s] \(segment.text.trimmingCharacters(in: .whitespaces))")

        // Optional: per-word timestamps
        if let words = segment.words {
            for wordTiming in words {
                print("  \(wordTiming.word): \(wordTiming.start)s - \(wordTiming.end)s")
            }
        }
    }
}

// Replacing the existing `results.map { $0.text }.joined()` pattern:
// OLD (loses segments):
//   let text = results.map { $0.text }.joined()
//
// NEW (preserves segments with timing):
//   let segments = results.flatMap { $0.segments }
//   // Use segments for SRT generation, subtitle display, etc.
```

---

## SRT format example

SRT (SubRip Subtitle) is a plain-text format. Each entry has:
1. Sequential index number
2. Timecode line: `HH:MM:SS,mmm --> HH:MM:SS,mmm` (comma as decimal separator for milliseconds)
3. Subtitle text (one or more lines)
4. Blank line separator

```
1
00:00:10,071 --> 00:00:11,671
[Speaker 0]: Life moves pretty fast.

2
00:00:12,100 --> 00:00:15,440
[Speaker 1]: You don't stop and look around once in a while.

3
00:00:16,020 --> 00:00:18,300
[Speaker 0]: You could miss it.
```

Swift helper to format seconds as SRT timecode:

```swift
func srtTimecode(_ seconds: Float) -> String {
    let totalMs = Int((seconds * 1000).rounded())
    let ms  = totalMs % 1000
    let s   = (totalMs / 1000) % 60
    let m   = (totalMs / 60_000) % 60
    let h   = totalMs / 3_600_000
    return String(format: "%02d:%02d:%02d,%03d", h, m, s, ms)
}
```

---

## Sources

- [Deepgram: Working with Timestamps, Utterances, and Speaker Diarization](https://deepgram.com/learn/working-with-timestamps-utterances-and-speaker-diarization-in-deepgram)
- [Deepgram Diarization Docs](https://developers.deepgram.com/docs/diarization)
- [Deepgram Utterances Docs](https://developers.deepgram.com/docs/utterances)
- [Deepgram REST API Reference](https://deepgram.rest/)
- [Deepgram Pricing](https://deepgram.com/pricing)
- [Deepgram Supported Audio Formats](https://developers.deepgram.com/docs/supported-audio-formats)
- [WhisperKit Models.swift (source of truth)](https://github.com/argmaxinc/WhisperKit/blob/main/Sources/WhisperKit/Core/Models.swift)
- [WhisperKit GitHub](https://github.com/argmaxinc/WhisperKit)
- [WhisperKit Transcription Guide (Transloadit)](https://transloadit.com/devtips/transcribe-audio-on-ios-macos-whisperkit/)
- [WhisperKit TranscriptionSegment IDs Discussion](https://github.com/argmaxinc/WhisperKit/issues/258)

---

## Limitations

1. **Deepgram diarization accuracy**: Nova-2/Nova-3 diarization works best with clean audio with clear speaker turns. Overlapping speech may produce incorrect speaker assignments.
2. **Deepgram file size**: Large video files (e.g., long MOV recordings) should be checked against Deepgram's file size limits (typically 2 GB for binary upload).
3. **WhisperKit word timestamps**: `words: [WordTiming]?` is only populated when `DecodingOptions.wordTimestamps = true`. The current `Transcriber.swift` does not set this option — needs to be added.
4. **WhisperKit speaker diarization**: WhisperKit does NOT support speaker diarization. It only provides timestamped segments without speaker labels. For speaker diarization with on-device processing, a separate speaker diarization model or Deepgram's cloud API is required.
5. **MOV support**: Deepgram's documentation primarily lists audio formats. MOV is a video container — it should work (audio track extracted), but should be tested with a sample file before shipping.
6. **Deepgram Content-Type for binary upload**: Must match the actual file format. Incorrect Content-Type may cause a 4xx error.
