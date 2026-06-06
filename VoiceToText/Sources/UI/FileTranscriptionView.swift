import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers

// MARK: - FileTranscriptionView

struct FileTranscriptionView: View {

    // MARK: - Props

    var appState: AppState? = nil
    var onClose: (() -> Void)? = nil

    // MARK: - State

    @StateObject private var transcriber = FileTranscriber()

    @State private var viewState: ViewState = .empty
    @State private var selectedMode: FileTranscriptionMode = .local
    @State private var selectedLanguage: String = "auto"
    @State private var isTargeted: Bool = false

    @State private var droppedFileURL: URL? = nil
    @State private var fileName: String = ""

    @State private var result: FileTranscriptionResult? = nil
    @State private var exportFormat: ExportFormat = .txt

    @State private var errorMessage: String? = nil
    @State private var showError: Bool = false

    @State private var transcriptionTask: Task<Void, Never>? = nil
    @State private var showHelp: Bool = false

    // MARK: - Allowed extensions

    private let allowedExtensions = ["mp3", "mp4", "wav", "m4a", "mov"]

    // MARK: - View State

    enum ViewState {
        case empty
        case processing
        case result
    }

    // MARK: - Speaker Colors

    private let speakerColors: [Color] = [
        Color.blue.opacity(0.18),
        Color.purple.opacity(0.18),
        Color.green.opacity(0.18),
        Color.orange.opacity(0.18),
        Color.pink.opacity(0.18),
        Color.teal.opacity(0.18)
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topToolbar
                Divider()
                    .background(Color.white.opacity(0.08))

                switch viewState {
                case .empty:
                    emptyStateView
                case .processing:
                    processingView
                case .result:
                    if let result = result {
                        resultView(result)
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(errorMessage ?? "An unknown error occurred.")
        })
    }

    // MARK: - Top Toolbar

    private var topToolbar: some View {
        HStack(spacing: 12) {
            // Close button
            Button(action: { onClose?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            Text("File Transcription")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))

            Button(action: { showHelp.toggle() }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.35))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showHelp, arrowEdge: .bottom) {
                helpPopover
            }

            Spacer()

            // Mode picker
            Picker("Mode", selection: $selectedMode) {
                Text("Local (WhisperKit)").tag(FileTranscriptionMode.local)
                Text("Deepgram + Speakers").tag(FileTranscriptionMode.deepgram)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)
            .disabled(viewState == .processing)

            // Language picker
            Picker("Language", selection: $selectedLanguage) {
                Text("Auto").tag("auto")
                Text("Russian").tag("ru")
                Text("English").tag("en")
                Text("German").tag("de")
                Text("Spanish").tag("es")
                Text("French").tag("fr")
                Text("Chinese").tag("zh")
                Text("Japanese").tag("ja")
            }
            .frame(maxWidth: 110)
            .disabled(viewState == .processing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack {
            Spacer()
            dropZone
            Spacer()
        }
        .padding(24)
    }

    private var dropZone: some View {
        VStack(spacing: 20) {
            Image(systemName: isTargeted ? "arrow.down.doc.fill" : "doc.badge.plus")
                .font(.system(size: 52, weight: .light))
                .foregroundColor(isTargeted ? .blue : .white.opacity(0.35))
                .animation(.easeInOut(duration: 0.15), value: isTargeted)

            VStack(spacing: 6) {
                Text("Drop audio or video file here")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(isTargeted ? .blue : .white.opacity(0.75))

                Text("Supported: mp3, mp4, wav, m4a, mov")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
            }

            Button(action: openFilePanel) {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                    Text("Open File…")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.75))
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: 480, maxHeight: 280)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isTargeted ? Color.blue.opacity(0.08) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isTargeted ? Color.blue.opacity(0.7) : Color.white.opacity(0.12),
                            style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: [6, 4])
                        )
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Processing State

    private var processingView: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.blue.opacity(0.8))

                Text(fileName)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 360)
            }

            VStack(spacing: 10) {
                ProgressView(value: transcriber.progress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                    .frame(maxWidth: 360)

                Text(transcriber.status)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
                    .animation(.easeInOut, value: transcriber.status)
            }

            Button(action: cancelTranscription) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(24)
    }

    // MARK: - Result State

    @ViewBuilder
    private func resultView(_ result: FileTranscriptionResult) -> some View {
        VStack(spacing: 0) {
            // Segments scroll area
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(result.segments.enumerated()), id: \.offset) { index, segment in
                        segmentRow(segment: segment, index: index, hasSpeakers: result.hasSpeakers)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }

            Divider()
                .background(Color.white.opacity(0.08))

            // Bottom toolbar
            resultToolbar(result)
        }
    }

    @ViewBuilder
    private func segmentRow(segment: FileTranscriptionSegment, index: Int, hasSpeakers: Bool) -> some View {
        let timestamp = formatTimestamp(start: segment.start, end: segment.end)
        let bgColor: Color = hasSpeakers
            ? speakerColors[(segment.speaker ?? 0) % speakerColors.count]
            : (index % 2 == 0 ? Color.white.opacity(0.03) : Color.clear)

        HStack(alignment: .top, spacing: 10) {
            if hasSpeakers {
                Text("S\((segment.speaker ?? 0) + 1)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(speakerLabelColor(for: segment.speaker ?? 0))
                    .frame(width: 22, height: 22)
                    .background(speakerLabelColor(for: segment.speaker ?? 0).opacity(0.15))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(timestamp)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))

                Text(segment.text)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(bgColor)
        )
    }

    private func speakerLabelColor(for speaker: Int) -> Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .teal]
        return colors[speaker % colors.count]
    }

    @ViewBuilder
    private func resultToolbar(_ result: FileTranscriptionResult) -> some View {
        HStack(spacing: 12) {
            // Copy button
            Button(action: { copyToClipboard(result) }) {
                HStack(spacing: 5) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                    Text("Copy")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.75))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 18)
                .background(Color.white.opacity(0.12))

            // Format picker
            Picker("Format", selection: $exportFormat) {
                ForEach(ExportFormat.allCases) { fmt in
                    Text(fmt.rawValue.uppercased()).tag(fmt)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)

            // Export button
            Button(action: { exportResult(result) }) {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                    Text("Export")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.75))
                )
            }
            .buttonStyle(.plain)

            Spacer()

            // New file button
            Button(action: resetToEmpty) {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 12))
                    Text("New File")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Help Popover

    private var helpPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How File Transcription works")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 10) {
                helpRow(
                    icon: "cpu",
                    title: "Local (WhisperKit)",
                    body: "Uses the same Whisper model you selected in Settings — no internet required. Transcription runs entirely on your Mac. No speaker detection."
                )
                helpRow(
                    icon: "waveform.and.mic",
                    title: "Deepgram + Speakers",
                    body: "Sends the file to Deepgram cloud API. Detects who said what (diarization). Requires a Deepgram API key in Settings → Cloud."
                )
            }

            Divider()

            Text("Supported formats: mp3, mp4, wav, m4a, mov")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 320)
    }

    private func helpRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(body)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Actions

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.title = "Select Audio or Video File"
        panel.allowedContentTypes = [
            UTType.mp3,
            UTType.mpeg4Audio,
            UTType.wav,
            UTType.audio,
            UTType.movie,
            UTType.quickTimeMovie
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        startTranscription(url: url)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard
                let data = item as? Data,
                let url = URL(dataRepresentation: data, relativeTo: nil)
            else { return }

            let ext = url.pathExtension.lowercased()
            guard allowedExtensions.contains(ext) else {
                DispatchQueue.main.async {
                    errorMessage = "Unsupported file type: \(ext). Allowed: \(allowedExtensions.joined(separator: ", "))"
                    showError = true
                }
                return
            }

            DispatchQueue.main.async {
                startTranscription(url: url)
            }
        }
        return true
    }

    private func startTranscription(url: URL) {
        droppedFileURL = url
        fileName = url.lastPathComponent
        transcriber.transcriber = appState?.transcriber
        viewState = .processing

        transcriptionTask = Task {
            do {
                let transcriptionResult = try await transcriber.transcribe(
                    fileURL: url,
                    mode: selectedMode,
                    language: selectedLanguage
                )
                await MainActor.run {
                    result = transcriptionResult
                    viewState = .result
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    viewState = .empty
                }
            }
        }
    }

    private func cancelTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        viewState = .empty
    }

    private func resetToEmpty() {
        result = nil
        droppedFileURL = nil
        fileName = ""
        viewState = .empty
    }

    private func copyToClipboard(_ result: FileTranscriptionResult) {
        let text = TranscriptionExporter.format(result, as: exportFormat)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func exportResult(_ result: FileTranscriptionResult) {
        let suggestedName = droppedFileURL?.deletingPathExtension().lastPathComponent ?? "transcription"
        Task {
            _ = await TranscriptionExporter.export(result, format: exportFormat, suggestedName: suggestedName)
        }
    }

    // MARK: - Helpers

    private func formatTimestamp(start: Float, end: Float) -> String {
        "\(secondsToTimestamp(start)) \u{2192} \(secondsToTimestamp(end))"
    }

    private func secondsToTimestamp(_ seconds: Float) -> String {
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
}

// MARK: - Preview

#if DEBUG
struct FileTranscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        FileTranscriptionView()
            .frame(width: 680, height: 520)
    }
}
#endif
