import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers

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
    @State private var showHelp: Bool = false

    @State private var transcriptionTask: Task<Void, Never>? = nil

    private let allowedExtensions = ["mp3", "mp4", "wav", "m4a", "mov"]

    enum ViewState { case empty, processing, result }

    private let speakerLabels = ["S1", "S2", "S3", "S4", "S5", "S6"]

    // MARK: - Body

    var body: some View {
        ZStack {
            Amber.bg
            ScanlineOverlay()

            VStack(spacing: 0) {
                topToolbar
                AmberDivider()

                switch viewState {
                case .empty:      emptyStateView
                case .processing: processingView
                case .result:
                    if let result = result { resultView(result) }
                }
            }
        }
        .amberBorder()
        .shadow(color: Amber.primary.opacity(0.10), radius: 16, x: 0, y: 6)
        .alert("Error", isPresented: $showError, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(errorMessage ?? "An unknown error occurred.")
        })
    }

    // MARK: - Top Toolbar

    private var topToolbar: some View {
        HStack(spacing: 0) {
            // Close
            Button(action: { onClose?() }) {
                Text("[X]")
                    .font(.amber(13, weight: .bold))
                    .foregroundColor(Amber.bright)
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(Amber.bgHeader)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("SPEAKYFI")
                .font(.amber(13, weight: .bold))
                .foregroundColor(Amber.bright)
                .amberGlow(4)

            Text(" // FILE TRANSCRIPTION")
                .font(.amber(12))
                .foregroundColor(Amber.dim)

            // Help
            Button(action: { showHelp.toggle() }) {
                Text("[?]")
                    .font(.amber(11))
                    .foregroundColor(Amber.faint)
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showHelp, arrowEdge: .bottom) {
                helpPopover
            }

            Spacer()

            // Mode picker
            HStack(spacing: 0) {
                modeBtn("LOCAL", mode: .local)
                Text("│").font(.amber(11)).foregroundColor(Amber.faint)
                modeBtn("DEEPGRAM", mode: .deepgram)
            }
            .padding(.horizontal, 6)

            Text("│").font(.amber(11)).foregroundColor(Amber.faint)

            // Language
            Menu {
                Button("AUTO") { selectedLanguage = "auto" }
                Button("RU")   { selectedLanguage = "ru" }
                Button("EN")   { selectedLanguage = "en" }
                Button("DE")   { selectedLanguage = "de" }
                Button("ES")   { selectedLanguage = "es" }
                Button("FR")   { selectedLanguage = "fr" }
                Button("ZH")   { selectedLanguage = "zh" }
                Button("JA")   { selectedLanguage = "ja" }
            } label: {
                Text("LANG:\(selectedLanguage.uppercased())")
                    .font(.amber(11))
                    .foregroundColor(Amber.dim)
                    .padding(.horizontal, 8)
            }
            .disabled(viewState == .processing)
        }
        .frame(height: 26)
        .background(Amber.bgHeader)
    }

    private func modeBtn(_ label: String, mode: FileTranscriptionMode) -> some View {
        Button(action: { selectedMode = mode }) {
            Text(label)
                .font(.amber(11, weight: selectedMode == mode ? .bold : .regular))
                .foregroundColor(selectedMode == mode ? Amber.bright : Amber.dim)
                .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .disabled(viewState == .processing)
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
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("C:\\> speakyfi.exe --transcribe-file")
                    .font(.amber(12))
                    .foregroundColor(Amber.faint)
                Text(isTargeted ? "DROP FILE NOW" : "DROP AUDIO/VIDEO FILE HERE")
                    .font(.amber(13, weight: .bold))
                    .foregroundColor(isTargeted ? Amber.bright : Amber.primary)
                    .amberGlow(isTargeted ? 6 : 2)
                Text("SUPPORTED: MP3  MP4  WAV  M4A  MOV")
                    .font(.amber(11))
                    .foregroundColor(Amber.faint)
            }

            Button(action: openFilePanel) {
                Text("[ OPEN FILE... ]")
                    .font(.amber(13, weight: .bold))
                    .foregroundColor(Amber.bright)
                    .amberGlow(3)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .overlay(Rectangle().stroke(Amber.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: 480, maxHeight: 260)
        .overlay(
            Rectangle()
                .stroke(
                    isTargeted ? Amber.bright : Amber.borderFaint,
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [6, 4])
                )
        )
        .animation(.easeInOut(duration: 0.12), value: isTargeted)
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Processing State

    private var processingView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // File info row
            HStack {
                Text("FILE:")
                    .font(.amber(11))
                    .foregroundColor(Amber.dim)
                Text(fileName)
                    .font(.amber(11))
                    .foregroundColor(Amber.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            AmberDivider()

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("C:\\> TRANSCRIBING...")
                    .font(.amber(12))
                    .foregroundColor(Amber.faint)

                // ASCII progress bar
                GeometryReader { geo in
                    let total = Int((geo.size.width - 16) / 8)
                    let filled = Int(Double(total) * transcriber.progress)
                    let empty = max(0, total - filled)
                    HStack(spacing: 0) {
                        Text("[")
                            .font(.amber(13))
                            .foregroundColor(Amber.dim)
                        Text(String(repeating: "█", count: filled))
                            .font(.amber(13))
                            .foregroundColor(Amber.hot)
                            .amberGlow(2)
                        Text(String(repeating: "─", count: empty))
                            .font(.amber(13))
                            .foregroundColor(Amber.faint)
                        Text("] \(Int(transcriber.progress * 100))%")
                            .font(.amber(13))
                            .foregroundColor(Amber.dim)
                    }
                    .animation(.easeInOut(duration: 0.3), value: transcriber.progress)
                }
                .frame(height: 16)

                Text(transcriber.status.uppercased())
                    .font(.amber(11))
                    .foregroundColor(Amber.dim)
                    .animation(.easeInOut, value: transcriber.status)
            }
            .padding(.horizontal, 12)

            Spacer()

            AmberDivider()

            // Cancel
            HStack {
                Button(action: cancelTranscription) {
                    Text("[ CANCEL ]")
                        .font(.amber(12))
                        .foregroundColor(Amber.dim)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Spacer()
            }
        }
    }

    // MARK: - Result State

    @ViewBuilder
    private func resultView(_ result: FileTranscriptionResult) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(result.segments.enumerated()), id: \.offset) { index, segment in
                        segmentRow(segment: segment, index: index, hasSpeakers: result.hasSpeakers)
                        AmberDivider()
                    }
                }
                .padding(.vertical, 4)
            }

            AmberDivider()
            resultToolbar(result)
        }
    }

    @ViewBuilder
    private func segmentRow(segment: FileTranscriptionSegment, index: Int, hasSpeakers: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Timestamp
            Text(formatTimestamp(start: segment.start, end: segment.end))
                .font(.amber(11))
                .foregroundColor(Amber.faint)
                .frame(width: hasSpeakers ? 90 : 110, alignment: .leading)

            if hasSpeakers {
                Text(speakerLabels[(segment.speaker ?? 0) % speakerLabels.count])
                    .font(.amber(11, weight: .bold))
                    .foregroundColor(Amber.hot)
                    .frame(width: 20)
            }

            Text(segment.text)
                .font(.amber(13))
                .foregroundColor(Amber.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(index % 2 == 0 ? Amber.bg : Amber.bgHeader.opacity(0.3))
    }

    @ViewBuilder
    private func resultToolbar(_ result: FileTranscriptionResult) -> some View {
        HStack(spacing: 0) {
            Button(action: { copyToClipboard(result) }) {
                Text("[ COPY ]")
                    .font(.amber(12))
                    .foregroundColor(Amber.dim)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            Text("│").font(.amber(11)).foregroundColor(Amber.faint)

            // Format picker
            ForEach(ExportFormat.allCases) { fmt in
                Button(action: { exportFormat = fmt }) {
                    Text(fmt.rawValue.uppercased())
                        .font(.amber(11, weight: exportFormat == fmt ? .bold : .regular))
                        .foregroundColor(exportFormat == fmt ? Amber.bright : Amber.dim)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }

            Text("│").font(.amber(11)).foregroundColor(Amber.faint)

            Button(action: { exportResult(result) }) {
                Text("[ EXPORT ]")
                    .font(.amber(12, weight: .bold))
                    .foregroundColor(Amber.bright)
                    .amberGlow(2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: resetToEmpty) {
                Text("[ NEW FILE ]")
                    .font(.amber(11))
                    .foregroundColor(Amber.faint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .background(Amber.bgHeader.opacity(0.6))
    }

    // MARK: - Help Popover

    private var helpPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("// HOW FILE TRANSCRIPTION WORKS")
                .font(.amber(13, weight: .bold))
                .foregroundColor(Amber.bright)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("[LOCAL]")
                        .font(.amber(12, weight: .bold))
                        .foregroundColor(Amber.hot)
                    Text("Uses the Whisper model loaded in Settings.\nNo internet. No speaker detection.")
                        .font(.amber(12))
                        .foregroundColor(Amber.dim)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("[DEEPGRAM]")
                        .font(.amber(12, weight: .bold))
                        .foregroundColor(Amber.hot)
                    Text("Sends file to Deepgram cloud API.\nDetects speakers. Requires API key in Settings.")
                        .font(.amber(12))
                        .foregroundColor(Amber.dim)
                }
            }

            Rectangle().fill(Amber.borderFaint).frame(height: 1)

            Text("FORMATS: MP3  MP4  WAV  M4A  MOV")
                .font(.amber(11))
                .foregroundColor(Amber.faint)
        }
        .padding(14)
        .frame(width: 300)
        .background(Amber.bg)
        .overlay(Rectangle().stroke(Amber.border, lineWidth: 1))
    }

    // MARK: - Actions

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.title = "Select Audio or Video File"
        panel.allowedContentTypes = [UTType.mp3, UTType.mpeg4Audio, UTType.wav, UTType.audio, UTType.movie, UTType.quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        startTranscription(url: url)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            let ext = url.pathExtension.lowercased()
            guard allowedExtensions.contains(ext) else {
                DispatchQueue.main.async {
                    errorMessage = "Unsupported file type: \(ext). Allowed: \(allowedExtensions.joined(separator: ", "))"
                    showError = true
                }
                return
            }
            DispatchQueue.main.async { startTranscription(url: url) }
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
                let res = try await transcriber.transcribe(fileURL: url, mode: selectedMode, language: selectedLanguage)
                await MainActor.run { result = res; viewState = .result }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; showError = true; viewState = .empty }
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
        Task { _ = await TranscriptionExporter.export(result, format: exportFormat, suggestedName: suggestedName) }
    }

    // MARK: - Helpers

    private func formatTimestamp(start: Float, end: Float) -> String {
        "\(secondsToTimestamp(start))→\(secondsToTimestamp(end))"
    }

    private func secondsToTimestamp(_ seconds: Float) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%02d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}

#if DEBUG
struct FileTranscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        FileTranscriptionView()
            .frame(width: 680, height: 520)
    }
}
#endif
