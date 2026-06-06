import SwiftUI
import AppKit

struct SplashView: View {
    var onDonate: () -> Void
    var onClose: () -> Void

    @ObservedObject private var l10n = L10nState.shared
    private let phrase: SplashPhrase = .random(isRussian: Locale.current.language.languageCode?.identifier == "ru")

    var body: some View {
        ZStack {
            Amber.bg
            ScanlineOverlay()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SPEAKYFI")
                        .font(.amber(14, weight: .bold))
                        .foregroundColor(Amber.bright)
                        .amberGlow(4)
                    Text(" [AMBER]")
                        .font(.amber(11))
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

                Spacer()

                // Emoji — render as terminal art
                Text(phrase.terminalIcon)
                    .font(.amber(36))
                    .foregroundColor(Amber.hot)
                    .amberGlow(6)

                // Phrase text
                Text(phrase.text)
                    .font(.amber(14))
                    .foregroundColor(Amber.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 14)

                Spacer()

                AmberDivider()

                // Support button
                Button(action: { onDonate(); onClose() }) {
                    Text("[ \(t(.splashSupport).uppercased()) ]")
                        .font(.amber(13, weight: .bold))
                        .foregroundColor(Amber.bright)
                        .amberGlow(3)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .overlay(Rectangle().stroke(Amber.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.vertical, 14)
            }
        }
        .frame(width: 340, height: 300)
        .amberBorder()
        .shadow(color: Amber.primary.opacity(0.10), radius: 16, x: 0, y: 6)
    }
}

// MARK: - Splash phrases

private struct SplashPhrase {
    let terminalIcon: String  // ASCII-friendly replacement for emoji
    let text: String
    let lang: String

    static let all: [SplashPhrase] = [
        // Russian
        .init(terminalIcon: ">_", text: "Speakyfi всё ещё бесплатный...\nно разработчик уже смотрит на цены в Пятёрочке", lang: "ru"),
        .init(terminalIcon: "C:\\", text: "Это приложение делал один человек в 3 ночи.\nПросто знай.", lang: "ru"),
        .init(terminalIcon: ">>",  text: "Speakyfi бесплатный,\nно автор не бесплатный.", lang: "ru"),
        .init(terminalIcon: ">_", text: "Если помогло — автор будет рад даже $1.\nЧестно.", lang: "ru"),
        .init(terminalIcon: "[]",  text: "Разработчик смотрит на кнопку [SUPPORT]\nи надеется.", lang: "ru"),
        .init(terminalIcon: "C:\\", text: "Speakyfi работает.\nАвтор — почти.", lang: "ru"),
        .init(terminalIcon: ">>",  text: "Сделано с любовью и без бюджета.", lang: "ru"),
        .init(terminalIcon: ">_", text: "Один человек. Один микрофон.\nНоль инвесторов.", lang: "ru"),
        .init(terminalIcon: "[]",  text: "Speakyfi: бесплатно для тебя,\nдорого для автора.", lang: "ru"),
        // English
        .init(terminalIcon: ">_", text: "Speakyfi is free.\nThe developer is not.", lang: "en"),
        .init(terminalIcon: "C:\\", text: "Made at 3am by one person.\nJust so you know.", lang: "en"),
        .init(terminalIcon: ">>",  text: "One human. One mic.\nZero investors.", lang: "en"),
        .init(terminalIcon: ">_", text: "Speakyfi works.\nThe developer — barely.", lang: "en"),
        .init(terminalIcon: "[]",  text: "Still free. Still hoping.", lang: "en"),
        .init(terminalIcon: "C:\\", text: "Built with love and no budget.", lang: "en"),
        .init(terminalIcon: ">>",  text: "The app is free but the developer\nchecks prices at the grocery store.", lang: "en"),
        .init(terminalIcon: ">_", text: "One person made this.\nHe's looking at [SUPPORT] right now.", lang: "en"),
        .init(terminalIcon: "[]",  text: "Free for you.\nExpensive for the author.", lang: "en"),
    ]

    static let russian: [SplashPhrase] = all.filter { $0.lang == "ru" }
    static let english: [SplashPhrase] = all.filter { $0.lang == "en" }

    static func random(isRussian: Bool) -> SplashPhrase {
        (isRussian ? russian : english).randomElement()!
    }
}
