import SwiftUI
import AppKit

struct DonateView: View {
    var onClose: () -> Void

    @ObservedObject private var l10n = L10nState.shared
    @State private var copied = false

    private let walletAddress = "TXmqkxLcegZwmqh2Lw82G7wbxU3sC7Zx93"

    var body: some View {
        ZStack {
            Amber.bg
            ScanlineOverlay()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SPEAKYFI")
                        .font(.amber(12, weight: .bold))
                        .foregroundColor(Amber.bright)
                        .amberGlow(4)
                    Text(" // SUPPORT")
                        .font(.amber(10))
                        .foregroundColor(Amber.dim)
                    Spacer()
                    Button(action: onClose) {
                        Text("[✕]")
                            .font(.amber(13, weight: .bold))
                            .foregroundColor(Amber.bright)
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 26)
                .background(Amber.bgHeader)

                AmberDivider()

                // Cat image
                if let catImage = loadCatImage() {
                    Image(nsImage: catImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 300, height: 160)
                        .clipped()
                        .overlay(Rectangle().stroke(Amber.borderFaint, lineWidth: 1))
                        .padding(.top, 14)
                        .padding(.horizontal, 20)
                } else {
                    Text(">_")
                        .font(.amber(48))
                        .foregroundColor(Amber.dim)
                        .padding(.top, 16)
                }

                // Caption
                Text(t(.donateCaption))
                    .font(.amber(12, weight: .bold))
                    .foregroundColor(Amber.bright)
                    .amberGlow(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Spacer()

                // Wallet
                AmberDivider()

                VStack(spacing: 8) {
                    Text("USDT TRC-20")
                        .font(.amber(9))
                        .foregroundColor(Amber.dim)

                    HStack(spacing: 8) {
                        Text(walletAddress)
                            .font(.amber(10))
                            .foregroundColor(Amber.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(Rectangle().stroke(Amber.borderFaint, lineWidth: 1))

                        Button(action: copyWallet) {
                            Text(copied ? "[OK]" : "[CPY]")
                                .font(.amber(10, weight: .bold))
                                .foregroundColor(copied ? Amber.ok : Amber.primary)
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.15), value: copied)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 340, height: 420)
        .amberBorder()
        .shadow(color: Amber.primary.opacity(0.10), radius: 16, x: 0, y: 6)
    }

    private func copyWallet() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(walletAddress, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }

    private func loadCatImage() -> NSImage? {
        let execURL = URL(fileURLWithPath: CommandLine.arguments[0])
        let bundleURL = execURL.deletingLastPathComponent()
            .appendingPathComponent("VoiceToText_VoiceToText.bundle")
        if let bundle = Bundle(url: bundleURL),
           let url = bundle.url(forResource: "cat", withExtension: "jpeg") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: "cat", withExtension: "jpeg") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}
