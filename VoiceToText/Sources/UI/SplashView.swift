import SwiftUI
import AppKit

struct SplashView: View {
    var onDonate: () -> Void
    var onClose: () -> Void

    @ObservedObject private var l10n = L10nState.shared
    private let phrase: SplashPhrase = .random(isRussian: Locale.current.language.languageCode?.identifier == "ru")

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(phrase.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 0) {
                HStack {
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

                Text(phrase.emoji)
                    .font(.system(size: 64))
                    .padding(.top, 12)

                Text(phrase.text)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 16)

                Spacer()

                Button(action: {
                    onDonate()
                    onClose()
                }) {
                    Text(t(.splashSupport))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 340, height: 300)
        .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 10)
    }
}

// MARK: - Фразы

private struct SplashPhrase {
    let emoji: String
    let text: String
    let background: Color
    let lang: String

    static let all: [SplashPhrase] = [
        // Русские
        .init(emoji: "🥺", text: "Speakyfi всё ещё бесплатный...\nно разработчик уже смотрит на цены в Пятёрочке 👉👈", background: .black.opacity(0.88), lang: "ru"),
        .init(emoji: "🥺", text: "Это приложение делал один человек в 3 ночи.\nПросто знай.", background: .black.opacity(0.88), lang: "ru"),
        .init(emoji: "👀", text: "Speakyfi бесплатный,\nно автор не бесплатный 🥺", background: .black.opacity(0.88), lang: "ru"),
        .init(emoji: "🥺", text: "Если это помогло — автор будет рад даже $1.\nЧестно.", background: .black.opacity(0.88), lang: "ru"),
        .init(emoji: "👉👈", text: "Разработчик смотрит на кнопку доната\nи надеется 🥺", background: .black.opacity(0.88), lang: "ru"),
        .init(emoji: "🥺", text: "Speakyfi работает.\nАвтор — почти.", background: .black.opacity(0.88), lang: "ru"),
        .init(emoji: "✨", text: "Сделано с любовью и без бюджета 🥺", background: .black.opacity(0.88), lang: "ru"),
        .init(emoji: "🎙", text: "Один человек. Один микрофон.\nНоль инвесторов. 🥺", background: .black.opacity(0.88), lang: "ru"),
        .init(emoji: "🥺", text: "Speakyfi: бесплатно для тебя,\nдорого для автора.", background: .black.opacity(0.88), lang: "ru"),
        // English
        .init(emoji: "🥺", text: "Speakyfi is free.\nThe developer is not.", background: .black.opacity(0.88), lang: "en"),
        .init(emoji: "🌙", text: "Made at 3am by one person.\nJust so you know. 🥺", background: .black.opacity(0.88), lang: "en"),
        .init(emoji: "🎙", text: "One human. One mic.\nZero investors. 🥺", background: .black.opacity(0.88), lang: "en"),
        .init(emoji: "🥺", text: "Speakyfi works.\nThe developer — barely.", background: .black.opacity(0.88), lang: "en"),
        .init(emoji: "👉👈", text: "Still free. Still hoping. 🥺", background: .black.opacity(0.88), lang: "en"),
        .init(emoji: "✨", text: "Built with love and no budget. 🥺", background: .black.opacity(0.88), lang: "en"),
        .init(emoji: "🛒", text: "The app is free but the developer\nchecks prices at the grocery store 🥺👉👈", background: .black.opacity(0.88), lang: "en"),
        .init(emoji: "👀", text: "One person made this.\nHe's looking at the donate button right now. 🥺", background: .black.opacity(0.88), lang: "en"),
        .init(emoji: "🥺", text: "Free for you.\nExpensive for the author.", background: .black.opacity(0.88), lang: "en"),
    ]

    static let russian: [SplashPhrase] = all.filter { $0.lang == "ru" }
    static let english: [SplashPhrase] = all.filter { $0.lang == "en" }

    static func random(isRussian: Bool) -> SplashPhrase {
        (isRussian ? russian : english).randomElement()!
    }
}
