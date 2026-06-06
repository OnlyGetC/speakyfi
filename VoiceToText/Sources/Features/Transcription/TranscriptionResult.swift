import Foundation

struct FileTranscriptionSegment {
    let start: Float
    let end: Float
    let text: String
    let speaker: Int?
}

struct FileTranscriptionResult {
    let segments: [FileTranscriptionSegment]
    let hasSpeakers: Bool

    var fullText: String {
        segments.map { $0.text }.joined(separator: " ")
    }
}
