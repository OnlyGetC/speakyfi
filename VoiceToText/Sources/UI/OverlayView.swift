import SwiftUI

struct OverlayView: View {
    @ObservedObject var appState: AppState
    var onClose: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.black.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 0) {
                HStack {
                    statusBadge
                    Spacer()
                    closeButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)

                if appState.modelLoading {
                    modelLoadingArea
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 18)
                } else {
                    WaveformView(level: appState.audioLevel, isRecording: appState.isRecording)
                        .frame(height: 72)
                        .padding(.horizontal, 18)
                        .padding(.top, 10)

                    textArea
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                        .padding(.bottom, 18)
                }
            }
        }
        .frame(width: 420, height: 260)
        .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 10)
    }

    // MARK: - Loading

    private var modelLoadingArea: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                // Спиннер
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
                    .tint(.white.opacity(0.6))

                Text(appState.modelProgressLabel.isEmpty ? "Загрузка модели..." : appState.modelProgressLabel)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                Text("\(Int(appState.modelProgress * 100))%")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Прогресс-бар
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), Color.white.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(appState.modelProgress), height: 4)
                        .animation(.easeInOut(duration: 0.3), value: appState.modelProgress)
                }
            }
            .frame(height: 4)

            Text("Первый запуск: модель загружается с HuggingFace (~500 МБ)")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.white.opacity(0.25))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Subviews

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(statusColor.opacity(0.4))
                        .frame(width: 16, height: 16)
                        .scaleEffect(appState.isRecording ? 1.2 : 0.8)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: appState.isRecording)
                )

            Text(statusText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var textArea: some View {
        Group {
            if appState.isTranscribing {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .scaleEffect(appState.isTranscribing ? 1.0 : 0.5)
                            .animation(
                                .easeInOut(duration: 0.5)
                                    .repeatForever()
                                    .delay(Double(i) * 0.15),
                                value: appState.isTranscribing
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if appState.lastText.isEmpty {
                Text("Удерживайте F4 для записи")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.25))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(appState.lastText)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.lastText)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        if appState.isRecording { return .red }
        if appState.isTranscribing { return .orange }
        if appState.modelLoading { return .yellow }
        return .green
    }

    private var statusText: String {
        if appState.modelLoading { return "Загрузка модели..." }
        if appState.isRecording { return appState.isVADMode ? "VAD · Запись" : "PTT · Запись" }
        if appState.isTranscribing { return "Обработка..." }
        if appState.isVADMode { return "VAD · Слушаю" }
        return "Готово"
    }
}
