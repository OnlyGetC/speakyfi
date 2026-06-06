import SwiftUI

// MARK: - Amber ASCII waveform

struct AmberWaveformView: View {
    var level: Float
    var isRecording: Bool

    private let barCount = 36
    @State private var phases: [Double] = (0..<36).map { _ in Double.random(in: 0...(.pi * 2)) }
    @State private var tick: Double = 0
    @State private var timer: Timer?

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { i in
                    let h = barHeight(index: i, totalHeight: geo.size.height)
                    Rectangle()
                        .fill(barColor(index: i))
                        .shadow(color: Amber.primary.opacity(0.4), radius: 2)
                        .frame(
                            width: max(1, (geo.size.width - CGFloat(barCount - 1) * 2) / CGFloat(barCount)),
                            height: h
                        )
                        .animation(.easeInOut(duration: 0.06), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private func barHeight(index: Int, totalHeight: CGFloat) -> CGFloat {
        let base: CGFloat = 2
        guard isRecording else {
            let idle = sin(phases[index] + tick * 0.6) * 0.08 + 0.10
            return max(base, totalHeight * CGFloat(idle))
        }
        let wave = sin(phases[index] + tick * 2.2) * 0.28 + 0.28
        let energy = CGFloat(level) * 0.65
        return max(base, min((CGFloat(wave) + energy) * totalHeight, totalHeight))
    }

    private func barColor(index: Int) -> Color {
        guard isRecording else { return Amber.faint }
        let center = Double(barCount) / 2
        let dist = abs(Double(index) - center) / center
        // Center bars are brighter
        let t = 1.0 - dist * 0.6
        return Color(
            red:   0.60 + 0.40 * t,
            green: 0.33 * t * Double(1 - level),
            blue:  0.00
        ).opacity(0.85 + t * 0.15)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { _ in tick += 1 }
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }
}

// MARK: - Legacy alias (OverlayView used WaveformView before)

typealias WaveformView = AmberWaveformView
