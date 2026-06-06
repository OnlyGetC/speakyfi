import Foundation
import AppKit

// MARK: - ExportFormat

enum ExportFormat: String, CaseIterable, Identifiable {
    case txt = "txt"
    case md  = "md"
    case srt = "srt"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .txt: return "Plain Text"
        case .md:  return "Markdown"
        case .srt: return "SubRip (.srt)"
        }
    }
}

// MARK: - TranscriptionExporter

struct TranscriptionExporter {

    // MARK: - Public API

    /// Opens NSSavePanel and writes the file. Returns true on success.
    @MainActor
    static func export(
        _ result: FileTranscriptionResult,
        format: ExportFormat,
        suggestedName: String
    ) async -> Bool {
        let panel = NSSavePanel()
        panel.title = "Export Transcription"
        panel.nameFieldStringValue = "\(suggestedName).\(format.rawValue)"
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = false
        panel.canCreateDirectories = true

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            return false
        }

        let content = Self.format(result, as: format)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    /// Pure conversion — no file I/O, useful for copy-to-clipboard.
    static func format(_ result: FileTranscriptionResult, as format: ExportFormat) -> String {
        switch format {
        case .txt: return formatTxt(result)
        case .md:  return formatMd(result)
        case .srt: return formatSrt(result)
        }
    }

    // MARK: - TXT

    private static func formatTxt(_ result: FileTranscriptionResult) -> String {
        if result.hasSpeakers {
            return result.segments
                .map { "[Speaker \($0.speaker ?? 0)] \($0.text)" }
                .joined(separator: "\n")
        } else {
            // Join all text, then wrap at ~80 chars on sentence boundaries
            let full = result.fullText
            let sentences = full.components(separatedBy: ". ")
            var lines: [String] = []
            var current = ""

            for (index, sentence) in sentences.enumerated() {
                let piece = index < sentences.count - 1 ? sentence + "." : sentence
                if current.isEmpty {
                    current = piece
                } else if (current.count + 1 + piece.count) <= 80 {
                    current += " " + piece
                } else {
                    lines.append(current)
                    current = piece
                }
            }
            if !current.isEmpty {
                lines.append(current)
            }
            return lines.joined(separator: "\n")
        }
    }

    // MARK: - Markdown

    private static func formatMd(_ result: FileTranscriptionResult) -> String {
        if result.hasSpeakers {
            return formatMdWithSpeakers(result)
        } else {
            return formatMdNoSpeakers(result)
        }
    }

    private static func formatMdWithSpeakers(_ result: FileTranscriptionResult) -> String {
        // Group consecutive segments by the same speaker
        var groups: [(speaker: Int, start: Float, end: Float, texts: [String])] = []

        for seg in result.segments {
            let speaker = seg.speaker ?? 0
            if let last = groups.last, last.speaker == speaker {
                var updated = groups.removeLast()
                updated.texts.append(seg.text)
                updated = (speaker: updated.speaker, start: updated.start, end: seg.end, texts: updated.texts)
                groups.append(updated)
            } else {
                groups.append((speaker: speaker, start: seg.start, end: seg.end, texts: [seg.text]))
            }
        }

        return groups.map { group in
            let ts = "\(mdTimestamp(group.start)) \u{2192} \(mdTimestamp(group.end))"
            let body = group.texts.joined(separator: " ")
            return "**Speaker \(group.speaker)** *(\(ts))*\n\(body)"
        }.joined(separator: "\n\n")
    }

    private static func formatMdNoSpeakers(_ result: FileTranscriptionResult) -> String {
        return result.segments.map { seg in
            let ts = "\(mdTimestamp(seg.start)) \u{2192} \(mdTimestamp(seg.end))"
            return "- *[\(ts)]* \(seg.text)"
        }.joined(separator: "\n")
    }

    // MARK: - SRT

    private static func formatSrt(_ result: FileTranscriptionResult) -> String {
        return result.segments.enumerated().map { index, seg in
            let prefix = result.hasSpeakers ? "[Speaker \(seg.speaker ?? 0)]: " : ""
            let start = srtTimecode(seg.start)
            let end   = srtTimecode(seg.end)
            return "\(index + 1)\n\(start) --> \(end)\n\(prefix)\(seg.text)"
        }.joined(separator: "\n\n")
    }

    // MARK: - Timestamp Helpers

    /// Format seconds as MM:SS or HH:MM:SS (if >= 1 hour).
    private static func mdTimestamp(_ seconds: Float) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    /// Format seconds as HH:MM:SS,mmm — SRT standard with comma as decimal separator.
    private static func srtTimecode(_ seconds: Float) -> String {
        let totalMs = Int((seconds * 1000).rounded())
        let ms = totalMs % 1000
        let totalSec = totalMs / 1000
        let s = totalSec % 60
        let totalMin = totalSec / 60
        let m = totalMin % 60
        let h = totalMin / 60
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, ms)
    }
}
