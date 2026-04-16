import SwiftUI
import TokenmonPersistence

/// Seven vertical bars (oldest -> newest, today on the right). Each bar is two
/// stacked segments: bottom = captures, top = escapes. Hovering a bar reveals
/// an inline label with the captured / escaped totals for that day.
struct DailyTrendBars: View {
    let buckets: [DailyEncounterBucket]

    @State private var hoveredIndex: Int?

    private static let weekdayLabels: [Int: String] = [
        1: "S", 2: "M", 3: "T", 4: "W", 5: "T", 6: "F", 7: "S",
    ]

    private var maxTotal: Int {
        max(1, buckets.map { $0.captures + $0.escapes }.max() ?? 0)
    }

    private func weekdayLabel(_ date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        return Self.weekdayLabels[weekday] ?? "?"
    }

    var body: some View {
        VStack(spacing: 4) {
            // Reserve space for the hover label so the chart doesn't shift
            // when a bar becomes hovered.
            hoverLabel
                .frame(height: 14)

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(buckets.indices, id: \.self) { index in
                    let bucket = buckets[index]
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            VStack(spacing: 1) {
                                Spacer(minLength: 0)
                                // Top: escapes (gray)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.55))
                                    .frame(
                                        height: max(0, geo.size.height * Double(bucket.escapes) / Double(maxTotal))
                                    )
                                // Bottom: captures (green)
                                Rectangle()
                                    .fill(Color.green)
                                    .frame(
                                        height: max(0, geo.size.height * Double(bucket.captures) / Double(maxTotal))
                                    )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .overlay(
                                hoveredIndex == index
                                    ? RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(Color.accentColor, lineWidth: 1)
                                    : nil
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 4)

                        Text(weekdayLabel(bucket.date))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(hoveredIndex == index ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        hoveredIndex = hovering ? index : (hoveredIndex == index ? nil : hoveredIndex)
                    }
                }
            }
            .frame(height: 62)
        }
    }

    @ViewBuilder
    private var hoverLabel: some View {
        if let index = hoveredIndex, buckets.indices.contains(index) {
            let bucket = buckets[index]
            HStack(spacing: 6) {
                Text(formatted(bucket.date))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(TokenmonL10n.format("trend.hover.captured", bucket.captures))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.green)
                Text(TokenmonL10n.format("trend.hover.escaped", bucket.escapes))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        } else {
            HStack {
                Text(TokenmonL10n.string("trend.hover.prompt"))
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.6))
                Spacer(minLength: 0)
            }
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
