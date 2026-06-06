import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var appState: AppState
    var onClose: () -> Void
    @ObservedObject private var l10n = L10nState.shared

    var body: some View {
        ZStack {
            Amber.bg
            ScanlineOverlay()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SPEAKYFI")
                        .font(.amber(13, weight: .bold))
                        .foregroundColor(Amber.bright)
                        .amberGlow(4)
                    Text(" // HISTORY")
                        .font(.amber(12))
                        .foregroundColor(Amber.dim)
                    Spacer()
                    Button(action: onClose) {
                        Text("[X]")
                            .font(.amber(13, weight: .bold))
                            .foregroundColor(Amber.bright)
                            .padding(.horizontal, 8)
                            .frame(height: 26)
                            .background(Amber.bgHeader)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(Amber.bgHeader)

                AmberDivider()

                // Status line
                HStack {
                    Text("ENTRIES: \(appState.history.count)")
                        .font(.amber(11))
                        .foregroundColor(Amber.dim)
                    Spacer()
                    Text("LAST 50")
                        .font(.amber(11))
                        .foregroundColor(Amber.faint)
                }
                .padding(.horizontal, 12)
                .frame(height: 20)

                AmberDivider()

                // Content
                if appState.history.isEmpty {
                    Spacer()
                    VStack(spacing: 6) {
                        Text("C:\\> history --list")
                            .font(.amber(12))
                            .foregroundColor(Amber.faint)
                        Text("NO ENTRIES FOUND")
                            .font(.amber(12))
                            .foregroundColor(Amber.dim)
                        BlinkingCursor()
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(appState.history) { entry in
                                AmberHistoryRow(entry: entry)
                                AmberDivider()
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 340, height: 420)
        .amberBorder()
        .shadow(color: Amber.primary.opacity(0.10), radius: 16, x: 0, y: 6)
    }
}

struct AmberHistoryRow: View {
    let entry: TranscriptionEntry
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.timeString)
                    .font(.amber(11))
                    .foregroundColor(Amber.dim)
                Text(entry.text)
                    .font(.amber(13))
                    .foregroundColor(Amber.primary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: copyEntry) {
                Text(copied ? "[OK]" : "[CPY]")
                    .font(.amber(11))
                    .foregroundColor(copied ? Amber.ok : Amber.dim)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.15), value: copied)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func copyEntry() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }
}
