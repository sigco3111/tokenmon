import SwiftUI
import TokenmonDomain

/// Four small vertical bars, one per field, with count on top and label below.
struct FieldDistributionBars: View {
    let counts: [FieldType: Int]

    private static let order: [FieldType] = [.grassland, .ice, .coast, .sky]

    private func color(for field: FieldType) -> Color {
        switch field {
        case .grassland: return Color.green
        case .ice: return Color(red: 0.78, green: 0.92, blue: 0.97)
        case .coast: return Color.teal
        case .sky: return Color.blue
        }
    }

    private func label(for field: FieldType) -> String {
        switch field {
        case .grassland: return "Grassland"
        case .ice: return "Ice"
        case .coast: return "Coast"
        case .sky: return "Sky"
        }
    }

    private var maxValue: Int {
        max(1, Self.order.map { counts[$0] ?? 0 }.max() ?? 0)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Self.order, id: \.self) { field in
                let value = counts[field] ?? 0
                VStack(spacing: 4) {
                    Text("\(value)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)

                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(color(for: field))
                                .frame(
                                    height: max(3, geo.size.height * Double(value) / Double(maxValue))
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 6)

                    Text(label(for: field))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 80)
    }
}
