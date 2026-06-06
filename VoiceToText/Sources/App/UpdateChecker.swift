import Foundation
import AppKit

// MARK: - Текущая версия приложения

let appVersion = "1.6.2"

// MARK: - UpdateChecker

enum UpdateCheckState {
    case idle
    case checking
    case upToDate
    case available(version: String, url: URL)
    case error(String)
}

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var state: UpdateCheckState = .idle

    private let apiURL = URL(string: "https://api.github.com/repos/OnlyGetC/speakyfi/releases/latest")!

    func check() {
        guard case .checking = state else {
            state = .checking
            Task { await fetchLatestRelease() }
            return
        }
    }

    private func fetchLatestRelease() async {
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String,
                  let releaseURL = URL(string: htmlURL) else {
                state = .error("Invalid response")
                return
            }

            let latest = tagName.trimmingCharacters(in: .init(charactersIn: "v"))
            if isNewer(latest, than: appVersion) {
                state = .available(version: latest, url: releaseURL)
            } else {
                state = .upToDate
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Возвращает true если `a` новее чем `b` (сравнение по компонентам)
    private func isNewer(_ a: String, than b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(aParts.count, bParts.count)
        for i in 0..<maxLen {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av != bv { return av > bv }
        }
        return false
    }

    func openReleasePage(url: URL) {
        NSWorkspace.shared.open(url)
    }
}
