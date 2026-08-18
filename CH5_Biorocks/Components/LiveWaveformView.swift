import SwiftUI

struct LiveWaveformView: View {
    let samples: [Double]
    var isLive = false

    var body: some View {
        Canvas { context, size in
            let bars = max(samples.count, 8)
            let spacing = 1.2
            let barWidth = max(1.2, (size.width - spacing * Double(bars - 1)) / Double(bars))
            let midY = size.height / 2
            let values = samples.isEmpty ? Array(repeating: 0.04, count: bars) : samples

            for (index, raw) in values.enumerated() {
                let amplitude = min(1, max(0.03, raw * 6))
                let height = max(2, amplitude * size.height)
                let x = Double(index) * (barWidth + spacing)
                let rect = CGRect(
                    x: x,
                    y: midY - height / 2,
                    width: barWidth,
                    height: height
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 1),
                    with: .color((isLive ? Color.green : Color.accentColor).opacity(samples.isEmpty ? 0.28 : 0.9))
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.18))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(isLive ? "Live hydrophone waveform" : "Hydrophone waveform")
    }
}
