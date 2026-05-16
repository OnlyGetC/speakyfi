import SwiftUI
import AppKit

struct OverlayView: View {
    @ObservedObject var appState: AppState
    var onClose: () -> Void
    var onSettings: () -> Void
    var onHistory: () -> Void

    @ObservedObject private var l10n = L10nState.shared
    @State private var copied = false

    var body: some View {
        ZStack {
            // Blur background
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            // Subtle overlay tint
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.35))

            // Border
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor.opacity(0.18), lineWidth: 1)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                if appState.modelLoading {
                    loadingArea
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .padding(.bottom, 14)
                } else {
                    contentArea
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                }
            }
        }
        .frame(width: pillWidth, height: contentHeight)
        .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appState.isRecording)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appState.isTranscribing)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appState.lastText)
    }

    // MARK: - Layout

    private var pillWidth: CGFloat { 340 }

    private var contentHeight: CGFloat {
        if appState.modelLoading      { return 140 }
        if appState.isRecording       { return 120 }
        if appState.isTranscribing    { return 100 }
        if !appState.lastText.isEmpty { return 160 }
        return 90
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 6) {
            // Статус-точка
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
                .scaleEffect(appState.isRecording ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: appState.isRecording)

            Text(statusText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.75))

            Spacer()

            // История
            iconButton(systemName: "clock", action: onHistory)

            // Настройки
            iconButton(systemName: "gearshape", action: onSettings)

            // Закрыть
            iconButton(systemName: "xmark", action: onClose)
        }
    }

    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 20, height: 20)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if appState.isRecording {
            recordingArea
        } else if appState.isTranscribing {
            transcribingArea
        } else if !appState.lastText.isEmpty {
            resultArea
        } else {
            idleArea
        }
    }

    private var recordingArea: some View {
        WaveformView(level: appState.audioLevel, isRecording: true)
            .frame(height: 44)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    private var transcribingArea: some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.65)
                .tint(.white.opacity(0.5))
            Text(t(.overlayTranscribing))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity)
    }

    private var resultArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            Text(appState.lastText)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.88))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(action: copyText) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(copied ? t(.overlayCopied) : t(.overlayCopy))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(copied ? .green : .white.opacity(0.55))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 7).fill(copied ? Color.green.opacity(0.12) : Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: copied)

                Spacer()

                Text(t(.overlayInserted))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white.opacity(0.18))
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var idleArea: some View {
        Text(idleHint)
            .font(.system(size: 11, design: .rounded))
            .foregroundColor(.white.opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .center)
            .transition(.opacity)
    }

    // MARK: - Loading

    private var loadingArea: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.65)
                    .tint(.white.opacity(0.5))
                Text(appState.modelProgressLabel.isEmpty ? t(.overlayStatusLoading) : appState.modelProgressLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                Spacer()
                Text("\(Int(appState.modelProgress * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.07)).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(appState.modelProgress), height: 3)
                        .animation(.easeInOut(duration: 0.3), value: appState.modelProgress)
                }
            }
            .frame(height: 3)
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        if appState.isRecording       { return .red }
        if appState.isTranscribing    { return .orange }
        if appState.modelLoading      { return .yellow }
        if !appState.lastText.isEmpty { return Color(red: 0.3, green: 0.85, blue: 0.5) }
        return Color.white.opacity(0.3)
    }

    private var borderColor: Color {
        if appState.isRecording    { return .red }
        if appState.isTranscribing { return .orange }
        return .white
    }

    private var statusText: String {
        if appState.modelLoading      { return t(.overlayStatusLoading) }
        if appState.isRecording       { return appState.isVADMode ? t(.overlayStatusVADRecording) : t(.overlayStatusRecording) }
        if appState.isTranscribing    { return t(.overlayStatusTranscribing) }
        if !appState.lastText.isEmpty { return t(.overlayStatusDone) }
        if appState.isVADMode         { return t(.overlayStatusVADListening) }
        return t(.overlayStatusReady)
    }

    private var idleHint: String {
        let ptt = HotkeyManager.shared.pttBinding.displayString
        return String(format: t(.overlayHoldToRecord), ptt)
    }

    private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(appState.lastText, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }
}

// MARK: - NSVisualEffectView wrapper

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
