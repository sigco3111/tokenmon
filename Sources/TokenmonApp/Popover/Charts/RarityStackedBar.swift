import SwiftUI
import TokenmonDomain

/// Single horizontal stacked bar with five rarity-colored segments. Basis: captured species.
struct RarityStackedBar: View {
    /// Counts must be keyed by every RarityTier; missing keys are treated as 0.
    let counts: [RarityTier: Int]

    private static let order: [RarityTier] = [.common, .uncommon, .rare, .epic, .legendary]

    private func color(for rarity: RarityTier) -> Color {
        switch rarity {
        case .common: return Color.gray
        case .uncommon: return Color.green
        case .rare: return Color.blue
        case .epic: return Color.purple
        case .legendary: return Color.yellow
        }
    }

    private func short(_ rarity: RarityTier) -> String {
        switch rarity {
        case .common: return "C"
        case .uncommon: return "U"
        case .rare: return "R"
        case .epic: return "E"
        case .legendary: return "L"
        }
    }

    private var total: Int {
        Self.order.reduce(0) { $0 + (counts[$1] ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(Self.order, id: \.self) { rarity in
                        let value = counts[rarity] ?? 0
                        let width = total > 0
                            ? geo.size.width * Double(value) / Double(total)
                            : 0
                        Rectangle()
                            .fill(color(for: rarity))
                            .frame(width: max(0, width - 1))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
            )

            HStack(spacing: 8) {
                ForEach(Self.order, id: \.self) { rarity in
                    HStack(spacing: 3) {
                        Circle().fill(color(for: rarity)).frame(width: 6, height: 6)
                        Text("\(short(rarity)) \(counts[rarity] ?? 0)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
