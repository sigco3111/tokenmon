import SwiftUI
import TokenmonDomain

// MARK: - Enablement Gate
//
// Dev-only: set to `true` to enable the ⌥⌘T live tuning panel.
// REMEMBER to flip this back to `false` before committing / pushing.
enum TokenmonDexCardTuningGate {
    static let isEnabled: Bool = false
}

// MARK: - Tuning Store

@MainActor
final class TokenmonDexCardTuningStore: ObservableObject {
    // Holographic overlay layer
    @Published var holoMultiplier: Double = 1.0
    @Published var glareMultiplier: Double = 1.0
    @Published var sparkleCountMultiplier: Double = 1.0
    @Published var sparkleOpacityMultiplier: Double = 1.0

    // Watermark and motion
    @Published var watermarkMultiplier: Double = 1.0
    @Published var tiltMultiplier: Double = 1.0

    @Published var panelVisible: Bool = false

    func resetAll() {
        holoMultiplier = 1.0
        glareMultiplier = 1.0
        sparkleCountMultiplier = 1.0
        sparkleOpacityMultiplier = 1.0
        watermarkMultiplier = 1.0
        tiltMultiplier = 1.0
    }
}

// MARK: - Style Application

extension TokenmonDexDetailCardStyle {
    @MainActor
    func applying(tuning: TokenmonDexCardTuningStore) -> TokenmonDexDetailCardStyle {
        TokenmonDexDetailCardStyle(
            shellEdgeGlow: shellEdgeGlow,
            hoverGlowBoost: hoverGlowBoost,
            frameHighlight: frameHighlight,
            auraOpacity: auraOpacity,
            foilOpacity: foilOpacity,
            hoverEdgeSweepOpacity: hoverEdgeSweepOpacity,
            glareOpacity: glareOpacity * tuning.glareMultiplier,
            hoverGlareBoost: hoverGlareBoost * tuning.glareMultiplier,
            shadowOpacity: shadowOpacity,
            hoverShadowBoost: hoverShadowBoost,
            frameGlossOpacity: frameGlossOpacity,
            shellCenterProtection: shellCenterProtection,
            artSurfaceTop: artSurfaceTop,
            artSurfaceBottom: artSurfaceBottom,
            artBackplateOpacity: artBackplateOpacity,
            artGlareOpacity: artGlareOpacity * tuning.glareMultiplier,
            artGlareWidth: artGlareWidth,
            shimmerAllowed: shimmerAllowed,
            shimmerOpacity: shimmerOpacity,
            shimmerDuration: shimmerDuration,
            shimmerZone: shimmerZone,
            pulseAllowed: pulseAllowed,
            stampSymbol: stampSymbol,
            surfaceTop: surfaceTop,
            surfaceBottom: surfaceBottom,
            primaryText: primaryText,
            secondaryText: secondaryText,
            foilTint: foilTint,
            foilAccent: foilAccent,
            holoOpacity: holoOpacity * tuning.holoMultiplier,
            holoGlareIntensity: holoGlareIntensity * tuning.glareMultiplier,
            sparkleCount: Int(Double(sparkleCount) * tuning.sparkleCountMultiplier),
            tiltStrength: tiltStrength * tuning.tiltMultiplier
        )
    }
}

// MARK: - Panel UI

struct TokenmonDexCardTuningPanel: View {
    @ObservedObject var store: TokenmonDexCardTuningStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Card Tuning")
                    .font(.headline)
                Spacer()
                Button("Reset") { store.resetAll() }
                    .controlSize(.small)
                Button {
                    store.panelVisible = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Section("Holographic") {
                        slider("Holo",           value: $store.holoMultiplier,            range: 0...2)
                        slider("Glare",          value: $store.glareMultiplier,           range: 0...2)
                        slider("Sparkle Count",  value: $store.sparkleCountMultiplier,    range: 0...2)
                        slider("Sparkle Opacity",value: $store.sparkleOpacityMultiplier,  range: 0...2)
                    }
                    Section("Motion / Media") {
                        slider("Watermark", value: $store.watermarkMultiplier, range: 0...2)
                        slider("Tilt",      value: $store.tiltMultiplier,      range: 0...2)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .frame(width: 300, height: 320)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
    }

    @ViewBuilder
    private func Section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.top, 4)
        content()
    }

    @ViewBuilder
    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(width: 92, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: "%.2f", value.wrappedValue))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}
