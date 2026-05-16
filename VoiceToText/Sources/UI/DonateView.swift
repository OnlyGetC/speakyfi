import SwiftUI
import AppKit

struct DonateView: View {
    var onClose: () -> Void

    @ObservedObject private var l10n = L10nState.shared
    @State private var copied = false

    private let walletAddress = "TXmqkxLcegZwmqh2Lw82G7wbxU3sC7Zx93"

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.black.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 0) {
                // Заголовок
                HStack {
                    Text(t(.donateTitle))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
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
                .padding(.horizontal, 20)
                .padding(.top, 18)

                Divider().background(Color.white.opacity(0.08)).padding(.top, 14)

                // Фото кота
                if let catImage = loadCatImage() {
                    Image(nsImage: catImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 300, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                } else {
                    Text("🐱")
                        .font(.system(size: 64))
                        .padding(.top, 16)
                }

                // Подпись
                Text(t(.donateCaption))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // Кошелёк
                VStack(spacing: 6) {
                    Text("USDT TRC-20")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.25))

                    HStack(spacing: 8) {
                        Text(walletAddress)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )

                        Button(action: copyWallet) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 13))
                                .foregroundColor(copied ? .green.opacity(0.8) : .white.opacity(0.4))
                                .animation(.easeInOut(duration: 0.15), value: copied)
                        }
                        .buttonStyle(.plain)
                        .help(t(.donateCopyAddress))
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 20)
                .padding(.horizontal, 20)
            }
        }
        .frame(width: 340, height: 440)
        .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 10)
    }

    private func copyWallet() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(walletAddress, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }

    private func loadCatImage() -> NSImage? {
        // SPM executable: ресурс лежит в VoiceToText_VoiceToText.bundle рядом с бинарём
        let execURL = URL(fileURLWithPath: CommandLine.arguments[0])
        let bundleURL = execURL.deletingLastPathComponent()
            .appendingPathComponent("VoiceToText_VoiceToText.bundle")
        if let bundle = Bundle(url: bundleURL),
           let url = bundle.url(forResource: "cat", withExtension: "jpeg") {
            return NSImage(contentsOf: url)
        }
        // Fallback: Bundle.main
        if let url = Bundle.main.url(forResource: "cat", withExtension: "jpeg") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}
