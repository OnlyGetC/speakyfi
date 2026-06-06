import SwiftUI
import AppKit

struct OverlayView: View {
    @ObservedObject var appState: AppState
    var onClose: () -> Void
    var onSettings: () -> Void
    var onHistory: () -> Void
    var onFileTranscription: () -> Void

    @ObservedObject private var l10n = L10nState.shared
    @State private var copied = false

    var body: some View {
        ZStack {
            Amber.bg
            ScanlineOverlay()

            VStack(spacing: 0) {
                headerBar.background(Amber.bgHeader)
                AmberDivider()
                statusBar
                AmberDivider()
                contentArea.frame(maxWidth: .infinity)
                AmberDivider()
                footerBar
            }
        }
        .frame(width: pillWidth, height: contentHeight)
        .amberBorder()
        .shadow(color: Amber.primary.opacity(0.12), radius: 20, x: 0, y: 6)
        .animation(.easeInOut(duration: 0.2), value: appState.isRecording)
        .animation(.easeInOut(duration: 0.2), value: appState.isTranscribing)
        .animation(.easeInOut(duration: 0.2), value: appState.lastText)
    }

    // MARK: - Layout

    private var pillWidth: CGFloat { 360 }

    private var contentHeight: CGFloat {
        if appState.modelLoading      { return 148 }
        if appState.isRecording       { return 130 }
        if appState.isTranscribing    { return 108 }
        if !appState.lastText.isEmpty { return 168 }
        return 98
    }

    // MARK: - Header bar

    private var headerBar: some View {
        HStack(spacing: 0) {
            Text("SPEAKYFI")
                .font(.amber(12, weight: .bold))
                .foregroundColor(Amber.bright)
                .amberGlow(5)
                .padding(.leading, 10)

            Text(" [AMBER]")
                .font(.amber(9))
                .foregroundColor(Amber.dim)

            Spacer()

            amberBtn("HIST", action: onHistory)
            amberBtn("FILE", action: onFileTranscription)
            amberBtn("CFG",  action: onSettings)

            // Close button — more visible, highlighted
            Button(action: onClose) {
                Text("[✕]")
                    .font(.amber(11, weight: .bold))
                    .foregroundColor(Amber.bright)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Amber.bgHeader.opacity(0.6))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(height: 24)
    }

    private func amberBtn(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("[\(label)]")
                .font(.amber(10))
                .foregroundColor(Amber.primary)
                .padding(.horizontal, 6)
                .frame(height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: statusDotColor.opacity(0.9), radius: 4)
                Text(statusLabel)
                    .font(.amber(10, weight: .medium))
                    .foregroundColor(statusLabelColor)
            }
            .padding(.leading, 10)

            Text("  │  ")
                .font(.amber(9))
                .foregroundColor(Amber.faint)

            Text("MODEL:\(appState.selectedLocalModel.rawValue.uppercased())")
                .font(.amber(9))
                .foregroundColor(Amber.dim)

            Spacer()

            Text(appState.transcriptionProvider == .cloud ? "CLOUD" : "LOCAL")
                .font(.amber(9))
                .foregroundColor(Amber.dim)
                .padding(.trailing, 10)
        }
        .frame(height: 22)
    }

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        if appState.modelLoading {
            loadingArea
        } else if appState.isRecording {
            recordingArea
        } else if appState.isTranscribing {
            transcribingArea
        } else if !appState.lastText.isEmpty {
            resultArea
        } else {
            idleArea
        }
    }

    // MARK: - Idle

    private var idleArea: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("C:\\> speakyfi.exe --listen")
                .font(.amber(9))
                .foregroundColor(Amber.faint)
            Text(idleHint)
                .font(.amber(11))
                .foregroundColor(Amber.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    // MARK: - Recording

    private var recordingArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECORDING... RELEASE [\(HotkeyManager.shared.pttBinding.displayString)]")
                .font(.amber(9))
                .foregroundColor(Amber.dim)
                .lineLimit(1)

            AmberWaveformView(level: appState.audioLevel, isRecording: true)
                .frame(height: 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .transition(.opacity)
    }

    // MARK: - Transcribing

    private var transcribingArea: some View {
        HStack(spacing: 8) {
            Text("C:\\>")
                .font(.amber(10))
                .foregroundColor(Amber.faint)
            Text("PROCESSING...")
                .font(.amber(11))
                .foregroundColor(Amber.primary)
            BlinkingCursor()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .transition(.opacity)
    }

    // MARK: - Result

    private var resultArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OUTPUT:")
                .font(.amber(9))
                .foregroundColor(Amber.dim)
                .padding(.leading, 10)
                .padding(.top, 8)

            Text(appState.lastText)
                .font(.amber(12))
                .foregroundColor(Amber.bright)
                .amberGlow(2)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)

            HStack(spacing: 0) {
                Button(action: copyText) {
                    Text(copied ? "[COPIED]" : "[COPY]")
                        .font(.amber(10))
                        .foregroundColor(copied ? Amber.ok : Amber.primary)
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: copied)
                .padding(.leading, 10)

                Spacer()

                Text("INSERTED")
                    .font(.amber(9))
                    .foregroundColor(Amber.dim)
                    .padding(.trailing, 10)
            }
            .padding(.bottom, 8)
        }
        .transition(.opacity)
    }

    // MARK: - Loading

    private var loadingArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("C:\\>")
                    .font(.amber(9))
                    .foregroundColor(Amber.faint)
                Text(appState.modelProgressLabel.isEmpty ? "LOADING MODEL..." : appState.modelProgressLabel.uppercased())
                    .font(.amber(10))
                    .foregroundColor(Amber.primary)
                Spacer()
                Text("\(Int(appState.modelProgress * 100))%")
                    .font(.amber(10, weight: .bold))
                    .foregroundColor(Amber.hot)
            }

            GeometryReader { geo in
                let total = Int((geo.size.width - 20) / 7)
                let filled = max(0, Int(Double(total) * appState.modelProgress))
                let empty = max(0, total - filled)
                HStack(spacing: 0) {
                    Text("[")
                        .font(.amber(10))
                        .foregroundColor(Amber.dim)
                    Text(String(repeating: "█", count: filled))
                        .font(.amber(10))
                        .foregroundColor(Amber.hot)
                        .amberGlow(2)
                    Text(String(repeating: "─", count: empty))
                        .font(.amber(10))
                        .foregroundColor(Amber.faint)
                    Text("]")
                        .font(.amber(10))
                        .foregroundColor(Amber.dim)
                }
                .animation(.easeInOut(duration: 0.3), value: appState.modelProgress)
            }
            .frame(height: 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    // MARK: - Footer bar

    private var footerBar: some View {
        HStack {
            Text("[⌃]REC  [⌘,]CFG  [⌘H]HIST")
                .font(.amber(8))
                .foregroundColor(Amber.dim)
                .padding(.leading, 10)
            Spacer()
            Text(appState.transcriptionProvider == .cloud ? "CLOUD" : "LOCAL")
                .font(.amber(8))
                .foregroundColor(Amber.faint)
                .padding(.trailing, 10)
        }
        .frame(height: 18)
    }

    // MARK: - Helpers

    private var statusDotColor: Color {
        if appState.isRecording       { return Color(red: 1, green: 0.3, blue: 0.3) }
        if appState.isTranscribing    { return Amber.warn }
        if appState.modelLoading      { return Amber.warn }
        if !appState.lastText.isEmpty { return Amber.ok }
        return Amber.dim
    }

    private var statusLabelColor: Color {
        if appState.isRecording       { return Color(red: 1, green: 0.5, blue: 0.5) }
        if appState.isTranscribing    { return Amber.warn }
        if appState.modelLoading      { return Amber.warn }
        if !appState.lastText.isEmpty { return Amber.ok }
        return Amber.dim
    }

    private var statusLabel: String {
        if appState.modelLoading      { return "LOADING" }
        if appState.isRecording       { return appState.isVADMode ? "VAD·REC" : "● REC" }
        if appState.isTranscribing    { return "PROCESSING" }
        if !appState.lastText.isEmpty { return "DONE" }
        if appState.isVADMode         { return "VAD·LISTEN" }
        return "READY"
    }

    private var idleHint: String {
        let key = HotkeyManager.shared.pttBinding.displayString
        return "HOLD [\(key)] TO RECORD"
    }

    private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(appState.lastText, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }
}

// MARK: - Blinking cursor

struct BlinkingCursor: View {
    @State private var visible = true
    let timer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    var body: some View {
        Rectangle()
            .fill(Amber.primary)
            .frame(width: 7, height: 12)
            .opacity(visible ? 1 : 0)
            .onReceive(timer) { _ in visible.toggle() }
    }
}
