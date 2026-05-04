import SwiftUI

struct WaveformView: View {
    var level: Float
    var isRecording: Bool

    private let barCount = 40
    @State private var phases: [Double] = (0..<40).map { _ in Double.random(in: 0...(.pi * 2)) }
    @State private var timer: Timer?
    @State private var tick: Double = 0

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(index: i))
                        .frame(width: max(1, (geo.size.width - CGFloat(barCount - 1) * 3) / CGFloat(barCount)))
                        .frame(height: barHeight(index: i, totalHeight: geo.size.height))
                        .animation(.easeInOut(duration: 0.08), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private func barHeight(index: Int, totalHeight: CGFloat) -> CGFloat {
        let base: CGFloat = 3
        guard isRecording else {
            // idle — тихая волна
            let idle = sin(phases[index] + tick * 0.8) * 0.12 + 0.14
            return max(base, totalHeight * CGFloat(idle))
        }

        let wave = sin(phases[index] + tick * 2.5) * 0.3 + 0.3
        let energy = CGFloat(level) * 0.7
        let height = (CGFloat(wave) + energy) * totalHeight
        return max(base, min(height, totalHeight))
    }

    private func barColor(index: Int) -> Color {
        guard isRecording else {
            return Color.white.opacity(0.12)
        }
        let center = Double(barCount) / 2
        let dist = abs(Double(index) - center) / center
        let alpha = 0.9 - dist * 0.5
        // Градиент: белый → красноватый в центре при высоком уровне
        let r = 1.0
        let g = max(0, 1.0 - Double(level) * 0.8)
        let b = max(0, 1.0 - Double(level) * 1.2)
        return Color(red: r, green: g, blue: b).opacity(alpha)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { _ in
            tick += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
