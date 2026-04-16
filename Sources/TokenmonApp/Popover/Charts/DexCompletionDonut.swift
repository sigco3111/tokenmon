import SwiftUI

/// Large ring chart showing percentage of species seen, with center percentage label
/// and a small caption underneath listing seen / captured counts.
struct DexCompletionDonut: View {
    let seenCount: Int
    let capturedCount: Int
    let totalCount: Int
    var diameter: CGFloat = 120
    var lineWidth: CGFloat = 14
    var showsCaption: Bool = true

    private var fraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(seenCount) / Double(totalCount)
    }

    private var percentLabel: String {
        let percent = Int((fraction * 100).rounded())
        return "\(percent)%"
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.18), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: fraction)

                Text(percentLabel)
                    .font(.system(size: diameter * 0.23, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: diameter, height: diameter)

            if showsCaption {
                Text(TokenmonL10n.format("dex.donut.caption", seenCount, totalCount, capturedCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
