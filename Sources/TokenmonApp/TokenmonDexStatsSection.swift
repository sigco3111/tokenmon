import SwiftUI
import TokenmonDomain
import TokenmonPersistence

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

private extension SpeciesStatAxis {
    var gradientColors: (start: Color, end: Color) {
        switch self {
        case .planning:
            return (Color(hex: 0x6366F1), Color(hex: 0x818CF8))
        case .design:
            return (Color(hex: 0x8B5CF6), Color(hex: 0xA78BFA))
        case .frontend:
            return (Color(hex: 0x06B6D4), Color(hex: 0x22D3EE))
        case .backend:
            return (Color(hex: 0x22C55E), Color(hex: 0x4ADE80))
        case .pm:
            return (Color(hex: 0xF59E0B), Color(hex: 0xFBBF24))
        case .infra:
            return (Color(hex: 0xEF4444), Color(hex: 0xF87171))
        }
    }

    var compactLabel: String {
        switch self {
        case .planning:
            return "Plan"
        case .design:
            return "Design"
        case .frontend:
            return "Front"
        case .backend:
            return "Back"
        case .pm:
            return "PM"
        case .infra:
            return "Infra"
        }
    }
}

private struct TokenmonDexStatMeter: View {
    let value: Int?
    let tint: (start: Color, end: Color)

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<10, id: \.self) { index in
                Capsule()
                    .fill(fill(for: index))
                    .frame(height: 4)
            }
        }
    }

    private func fill(for index: Int) -> LinearGradient {
        if let value, index < value {
            return LinearGradient(
                colors: [tint.start, tint.end],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        return LinearGradient(
            colors: [Color.secondary.opacity(0.18), Color.secondary.opacity(0.10)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private struct TokenmonDexStatCell: View {
    let axis: SpeciesStatAxis
    let value: Int?
    let locked: Bool
    let style: TokenmonDexDetailCardStyle

    var body: some View {
        let colors = axis.gradientColors

        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 4) {
                Text(axis.compactLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(style.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let value {
                    Text("\(value)")
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(colors.end)
                } else {
                    Image(systemName: locked ? "lock.fill" : "minus")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(style.secondaryText)
                }
            }

            TokenmonDexStatMeter(value: value, tint: colors)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            colors.start.opacity(locked ? 0.05 : 0.10),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(colors.end.opacity(locked ? 0.12 : 0.24), lineWidth: 1)
        )
    }
}

struct TokenmonDexCardTotalBadge: View {
    let total: Int
    let rarity: RarityTier

    var body: some View {
        HStack(spacing: 8) {
            Text("TOTAL")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            Text("\(total)")
                .font(.headline.monospacedDigit().weight(.bold))
                .foregroundStyle(rarity.tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(rarity.tint.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(rarity.tint.opacity(0.20), lineWidth: 1)
        )
    }
}

private struct TraitBadge: View {
    let trait: String
    let isDomain: Bool

    var body: some View {
        Text(trait)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(isDomain ? Color(hex: 0x818CF8) : Color(hex: 0xFBBF24))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(
                        isDomain
                        ? Color.indigo.opacity(0.20)
                        : Color.yellow.opacity(0.15)
                    )
            )
    }
}

private struct TagFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        y += rowHeight
        return CGSize(width: maxWidth, height: y)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct TokenmonDexStatsSection: View {
    let stats: SpeciesStatBlock
    let status: DexEntryStatus
    let rarity: RarityTier
    let style: TokenmonDexDetailCardStyle

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    var body: some View {
        if status == .unknown {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center) {
                    Text("Specs")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(style.secondaryText)
                    Spacer()
                    TokenmonDexCardTotalBadge(total: stats.total, rarity: rarity)
                }

                LazyVGrid(columns: columns, spacing: 5) {
                    ForEach(SpeciesStatAxis.allCases, id: \.self) { axis in
                        TokenmonDexStatCell(
                            axis: axis,
                            value: TokenmonDexPresentation.showsFullStatPlate(status: status) ? stats.value(for: axis) : nil,
                            locked: TokenmonDexPresentation.showsFullStatPlate(status: status) == false,
                            style: style
                        )
                    }
                }

                if let footnote = TokenmonDexPresentation.statsPlateFootnote(for: status) {
                    Text(footnote)
                        .font(.caption2)
                        .foregroundStyle(style.secondaryText)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                rarity.tint.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
    }
}
