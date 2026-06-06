import SwiftUI

// MARK: - Amber IBM color palette

enum Amber {
    // Core colors
    static let primary    = Color(red: 0.80, green: 0.53, blue: 0.00) // #cc8800
    static let bright     = Color(red: 1.00, green: 0.67, blue: 0.00) // #ffaa00
    static let hot        = Color(red: 1.00, green: 0.53, blue: 0.00) // #ff8800
    static let dim        = Color(red: 0.29, green: 0.19, blue: 0.00) // #4a3000
    static let faint      = Color(red: 0.16, green: 0.12, blue: 0.00) // #291e00
    static let bg         = Color(red: 0.04, green: 0.03, blue: 0.00) // #0a0800
    static let bgHeader   = Color(red: 0.23, green: 0.16, blue: 0.00) // #3a2800
    static let border     = Color(red: 0.23, green: 0.16, blue: 0.00) // #3a2800
    static let borderFaint = Color(red: 0.12, green: 0.08, blue: 0.00) // #1e1400

    // Semantic
    static let rec        = Color(red: 1.00, green: 0.27, blue: 0.27) // red-ish on amber bg
    static let ok         = Color(red: 0.27, green: 0.80, blue: 0.40) // green OK
    static let warn       = Color(red: 1.00, green: 0.67, blue: 0.00) // bright amber
}

// MARK: - Amber font

extension Font {
    /// Main monospaced font for amber UI
    static func amber(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Scanline overlay

struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: 0, y: y + 3, width: size.width, height: 1)
                    ctx.fill(Path(rect), with: .color(.black.opacity(0.08)))
                    y += 4
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Amber divider

struct AmberDivider: View {
    var body: some View {
        Rectangle()
            .fill(Amber.borderFaint)
            .frame(height: 1)
    }
}

// MARK: - Amber border frame

struct AmberBorder: ViewModifier {
    var cornerRadius: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Amber.border, lineWidth: 1.5)
            )
    }
}

extension View {
    func amberBorder(cornerRadius: CGFloat = 0) -> some View {
        modifier(AmberBorder(cornerRadius: cornerRadius))
    }
}

// MARK: - Glow text modifier

struct AmberGlow: ViewModifier {
    var radius: CGFloat = 4
    func body(content: Content) -> some View {
        content.shadow(color: Amber.primary.opacity(0.5), radius: radius)
    }
}

extension View {
    func amberGlow(_ radius: CGFloat = 4) -> some View {
        modifier(AmberGlow(radius: radius))
    }
}
