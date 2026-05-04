import Foundation
import Combine

class AppState: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var isTranscribing: Bool = false
    @Published var isVADMode: Bool = false
    @Published var modelReady: Bool = false
    @Published var modelLoading: Bool = true
    @Published var modelProgress: Double = 0.0      // 0.0 – 1.0
    @Published var modelProgressLabel: String = ""  // "Загрузка модели (12%)"
    @Published var audioLevel: Float = 0.0
    @Published var history: [TranscriptionEntry] = []
    @Published var lastText: String = ""

    let recorder = AudioRecorder()
    let transcriber = Transcriber()

    init() {
        transcriber.onReady = { [weak self] in
            DispatchQueue.main.async {
                self?.modelReady = true
                self?.modelLoading = false
                self?.modelProgress = 1.0
            }
        }
        transcriber.onProgress = { [weak self] progress, label in
            DispatchQueue.main.async {
                self?.modelProgress = progress
                self?.modelProgressLabel = label
            }
        }
        recorder.onLevelUpdate = { [weak self] level in
            DispatchQueue.main.async {
                self?.audioLevel = level
            }
        }
    }

    func addHistory(text: String) {
        let entry = TranscriptionEntry(text: text, timestamp: Date())
        history.insert(entry, at: 0)
        lastText = text
        if history.count > 50 {
            history.removeLast()
        }
    }
}

struct TranscriptionEntry: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: timestamp)
    }
}
