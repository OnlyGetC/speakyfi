import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var appState: AppState
    var onClose: () -> Void
    @ObservedObject private var l10n = L10nState.shared

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.35))

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)

            VStack(spacing: 0) {
                // Заголовок
                HStack {
                    Text(t(.historyTitle))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)

                if appState.history.isEmpty {
                    Spacer()
                    Text(t(.historyEmpty))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.25))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(appState.history) { entry in
                                HistoryRow(entry: entry)
                                Rectangle()
                                    .fill(Color.white.opacity(0.04))
                                    .frame(height: 1)
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 340, height: 420)
        .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 8)
    }
}

struct HistoryRow: View {
    let entry: TranscriptionEntry
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(entry.timeString)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
            }

            Button(action: copyEntry) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundColor(copied ? .green : .white.opacity(0.25))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.15), value: copied)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func copyEntry() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }
}
