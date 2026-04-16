import SwiftUI

struct TokenmonFieldMotionVector: Sendable {
    let exploring: CGSize
    let rustle: CGSize
    let settle: CGSize
    let period: Int
    let phase: Int

    func offset(for state: TokenmonFieldState, tick: Int) -> CGSize {
        let amplitude: CGSize
        switch state {
        case .calm, .unavailable:
            return .zero
        case .exploring:
            amplitude = exploring
        case .rustle:
            amplitude = rustle
        case .settle:
            amplitude = settle
        }

        let safePeriod = max(period, 1)
        let sample = (tick + phase) % safePeriod
        let horizontal = oscillate(sample: sample, period: safePeriod, amplitude: amplitude.width)
        let vertical = oscillate(sample: sample, period: safePeriod, amplitude: amplitude.height)
        return CGSize(width: horizontal, height: vertical)
    }

    private func oscillate(sample: Int, period: Int, amplitude: CGFloat) -> CGFloat {
        guard amplitude != 0 else {
            return 0
        }

        let pattern = [
            -amplitude,
            0,
            amplitude,
            0,
        ]
        let index = sample % pattern.count
        return pattern[index]
    }
}

struct TokenmonFieldMotionProfile: Sendable {
    let landmark: TokenmonFieldMotionVector
    let support: TokenmonFieldMotionVector
    let accent: TokenmonFieldMotionVector
}

struct TokenmonFieldPalette {
    let baseShadow: Color
    let baseMid: Color
    let baseHighlight: Color
    let landmarkShade: Color
    let landmarkMain: Color
    let support: Color
    let motion: Color
    let pocket: Color
    let backplateFill: Color
    let backplateStroke: Color
}

enum TokenmonFieldDominantCue: Sendable {
    case meadowStage
    case iceFlurry
    case cloudShelf
    case shoreline
    case neutral
}

enum TokenmonFieldSupportAccent: Sendable {
    case grasslandSprigs
    case iceCrystal
    case skyRibbon
    case coastDebris
    case none
    case neutral
}

enum TokenmonFieldMotionAccent: Sendable {
    case pollen
    case snowDrift
    case windMotes
    case seaSpray
    case dust
    case none
}

struct TokenmonFieldPreviewSpecies {
    let commonAssetKey: String
    let rareAssetKey: String
}

struct TokenmonFieldVisualSpec {
    let kind: TokenmonSceneFieldKind
    let palette: TokenmonFieldPalette
    let dominantCue: TokenmonFieldDominantCue
    let supportAccent: TokenmonFieldSupportAccent
    let motionAccent: TokenmonFieldMotionAccent
    let spawnPocket: CGRect
    let effectOffset: CGSize
    let landmarkOffset: CGPoint
    let supportOffset: CGPoint
    let motionOffset: CGPoint
    let motionProfile: TokenmonFieldMotionProfile

    func effectRect(in layout: TokenmonSceneLayout) -> CGRect {
        let fieldPatchRect = layout.fieldPatchRect
        let center = CGPoint(
            x: fieldPatchRect.midX + effectOffset.width,
            y: fieldPatchRect.midY + effectOffset.height
        )
        let effectSize = layout.effectFrame.size
        let unclampedOrigin = CGPoint(
            x: center.x - (effectSize.width / 2),
            y: center.y - (effectSize.height / 2)
        )
        let maxX = fieldPatchRect.maxX - effectSize.width
        let maxY = fieldPatchRect.maxY - effectSize.height
        let clampedOrigin = CGPoint(
            x: min(max(unclampedOrigin.x, fieldPatchRect.minX), maxX),
            y: min(max(unclampedOrigin.y, fieldPatchRect.minY), maxY)
        )

        return CGRect(
            x: round(clampedOrigin.x),
            y: round(clampedOrigin.y),
            width: effectSize.width,
            height: effectSize.height
        )
    }
}

extension TokenmonSceneFieldKind {
    var previewSpecies: TokenmonFieldPreviewSpecies? {
        switch self {
        case .grassland:
            return TokenmonFieldPreviewSpecies(
                commonAssetKey: "grs_001_mossbun",
                rareAssetKey: "grs_021_thornlynx"
            )
        case .ice:
            return TokenmonFieldPreviewSpecies(
                commonAssetKey: "ice_001_snowmole",
                rareAssetKey: "ice_021_aurora_lynx"
            )
        case .coast:
            return TokenmonFieldPreviewSpecies(
                commonAssetKey: "cst_001_foamcrab",
                rareAssetKey: "cst_021_tidefang"
            )
        case .sky:
            return TokenmonFieldPreviewSpecies(
                commonAssetKey: "sky_001_puffowl",
                rareAssetKey: "sky_021_stormheron"
            )
        case .unavailable:
            return nil
        }
    }

    var visualSpec: TokenmonFieldVisualSpec {
        switch self {
        case .grassland:
            return TokenmonFieldVisualSpec(
                kind: self,
                palette: TokenmonFieldPalette(
                    baseShadow: Color(red: 0.02, green: 0.08, blue: 0.02),
                    baseMid: Color(red: 0.07, green: 0.43, blue: 0.07),
                    baseHighlight: Color(red: 0.40, green: 0.87, blue: 0.32),
                    landmarkShade: Color(red: 0.04, green: 0.34, blue: 0.05),
                    landmarkMain: Color(red: 0.16, green: 0.70, blue: 0.14),
                    support: Color(red: 0.48, green: 0.90, blue: 0.34),
                    motion: Color(red: 0.48, green: 0.90, blue: 0.34),
                    pocket: Color.black.opacity(0.04),
                    backplateFill: Color(red: 0.11, green: 0.20, blue: 0.10).opacity(0.78),
                    backplateStroke: Color(red: 0.62, green: 0.88, blue: 0.45).opacity(0.34)
                ),
                dominantCue: .meadowStage,
                supportAccent: .none,
                motionAccent: .none,
                spawnPocket: CGRect(x: 18, y: 7, width: 11, height: 5),
                effectOffset: .zero,
                landmarkOffset: CGPoint(x: 1, y: 3),
                supportOffset: CGPoint(x: 0, y: 0),
                motionOffset: CGPoint(x: 0, y: 0),
                motionProfile: TokenmonFieldMotionProfile(
                    landmark: TokenmonFieldMotionVector(
                        exploring: CGSize(width: 2, height: 1),
                        rustle: CGSize(width: 3, height: 1),
                        settle: CGSize(width: 1, height: 0),
                        period: 4,
                        phase: 0
                    ),
                    support: TokenmonFieldMotionVector(
                        exploring: CGSize(width: 0, height: 1),
                        rustle: CGSize(width: 1, height: 1),
                        settle: CGSize(width: 0, height: 0),
                        period: 4,
                        phase: 1
                    ),
                    accent: TokenmonFieldMotionVector(
                        exploring: CGSize(width: 1, height: -1),
                        rustle: CGSize(width: 2, height: -1),
                        settle: CGSize(width: 1, height: 0),
                        period: 4,
                        phase: 2
                    )
                )
            )
        case .sky:
            return TokenmonFieldVisualSpec(
                kind: self,
                palette: TokenmonFieldPalette(
                    baseShadow: Color(red: 0.60, green: 0.74, blue: 0.95),
                    baseMid: Color(red: 0.79, green: 0.89, blue: 1.0),
                    baseHighlight: Color(red: 0.97, green: 0.99, blue: 1.0),
                    landmarkShade: Color(red: 0.69, green: 0.80, blue: 0.96),
                    landmarkMain: Color(red: 0.98, green: 0.99, blue: 1.0),
                    support: Color(red: 0.87, green: 0.93, blue: 1.0),
                    motion: Color(red: 0.87, green: 0.93, blue: 1.0),
                    pocket: Color.white.opacity(0.03),
                    backplateFill: Color(red: 0.45, green: 0.56, blue: 0.74).opacity(0.76),
                    backplateStroke: Color.white.opacity(0.34)
                ),
                dominantCue: .cloudShelf,
                supportAccent: .none,
                motionAccent: .none,
                spawnPocket: CGRect(x: 18, y: 5, width: 11, height: 6),
                effectOffset: .zero,
                landmarkOffset: CGPoint(x: 1, y: 2),
                supportOffset: CGPoint(x: 0, y: 0),
                motionOffset: CGPoint(x: 0, y: 0),
                motionProfile: TokenmonFieldMotionProfile(
                    landmark: TokenmonFieldMotionVector(
                        exploring: CGSize(width: 2, height: -1),
                        rustle: CGSize(width: 3, height: -1),
                        settle: CGSize(width: 1, height: 0),
                        period: 6,
                        phase: 1
                    ),
                    support: TokenmonFieldMotionVector(
                        exploring: CGSize(width: 0, height: 0),
                        rustle: CGSize(width: 0, height: 0),
                        settle: CGSize(width: 0, height: 0),
                        period: 1,
                        phase: 2
                    ),
                    accent: TokenmonFieldMotionVector(
                        exploring: CGSize(width: 0, height: 0),
                        rustle: CGSize(width: 0, height: 0),
                        settle: CGSize(width: 0, height: 0),
                        period: 1,
                        phase: 0
                    )
                )
            )
        case .coast:
            return TokenmonFieldVisualSpec(
                kind: self,
                palette: TokenmonFieldPalette(
                    baseShadow: Color(red: 0.05, green: 0.39, blue: 0.73),
                    baseMid: Color(red: 0.09, green: 0.63, blue: 0.90),
                    baseHighlight: Color(red: 0.98, green: 0.99, blue: 1.0),
                    landmarkShade: Color(red: 0.08, green: 0.48, blue: 0.82),
                    landmarkMain: Color(red: 0.43, green: 0.82, blue: 0.99),
                    support: Color(red: 0.83, green: 0.95, blue: 1.0),
                    motion: Color.white.opacity(0.95),
                    pocket: Color.black.opacity(0.04),
                    backplateFill: Color(red: 0.05, green: 0.22, blue: 0.40).opacity(0.80),
                    backplateStroke: Color(red: 0.63, green: 0.89, blue: 1.0).opacity(0.34)
                ),
                dominantCue: .shoreline,
                supportAccent: .none,
                motionAccent: .none,
                spawnPocket: CGRect(x: 18, y: 6, width: 10, height: 5),
                effectOffset: .zero,
                landmarkOffset: CGPoint(x: 1, y: 6),
                supportOffset: CGPoint(x: 0, y: 0),
                motionOffset: CGPoint(x: 0, y: 0),
                motionProfile: TokenmonFieldMotionProfile(
                    landmark: TokenmonFieldMotionVector(
                        exploring: CGSize(width: 2, height: 0),
                        rustle: CGSize(width: 3, height: -1),
                        settle: CGSize(width: 1, height: 0),
                        period: 6,
                        phase: 2
                    ),
                    support: TokenmonFieldMotionVector(
                        exploring: CGSize(width: 0, height: 0),
                        rustle: CGSize(width: 0, height: 0),
                        settle: CGSize(width: 0, height: 0),
                        period: 1,
                        phase: 1
                    ),
                    accent: TokenmonFieldMotionVector(
                        exploring: CGSize(width: 0, height: 0),
                        rustle: CGSize(width: 0, height: 0),
                        settle: CGSize(width: 0, height: 0),
                        period: 1,
                        phase: 0
                    )
                )
            )
        case .ice:
            return TokenmonFieldVisualSpec(
                kind: self,
                palette: TokenmonFieldPalette(
                    baseShadow: Color(red: 0.44, green: 0.63, blue: 0.86),
                    baseMid: Color(red: 0.72, green: 0.86, blue: 0.98),
                    baseHighlight: Color(red: 0.95, green: 0.99, blue: 1.0),
                    landmarkShade: Color(red: 0.58, green: 0.74, blue: 0.92),
                    landmarkMain: Color(red: 0.90, green: 0.97, blue: 1.0),
                    support: Color(red: 0.67, green: 0.90, blue: 1.0),
                    motion: Color(red: 0.93, green: 0.98, blue: 1.0),
                    pocket: Color.white.opacity(0.05),
                    backplateFill: Color(red: 0.24, green: 0.35, blue: 0.51).opacity(0.80),
                    backplateStroke: Color(red: 0.82, green: 0.94, blue: 1.0).opacity(0.36)
                ),
                dominantCue: .iceFlurry,
                supportAccent: .none,
                motionAccent: .snowDrift,
                spawnPocket: CGRect(x: 19, y: 5, width: 10, height: 6),
                effectOffset: .zero,
                landmarkOffset: CGPoint(x: 1, y: 2),
                supportOffset: CGPoint(x: 0, y: 0),
                motionOffset: CGPoint(x: 0, y: 0),
                motionProfile: TokenmonFieldMotionProfile(
                    landmark: TokenmonFieldMotionVector(
                        exploring: CGSize(width: 2, height: -1),
                        rustle: CGSize(width: 3, height: -1),
                        settle: CGSize(width: 1, height: 0),
                        period: 6,
                        phase: 1
                    ),
                    support: TokenmonFieldMotionVector(
                        exploring: CGSize(width: 1, height: 0),
                        rustle: CGSize(width: 2, height: -1),
                        settle: CGSize(width: 0, height: 0),
                        period: 6,
                        phase: 3
                    ),
                    accent: TokenmonFieldMotionVector(
                        exploring: CGSize(width: 1, height: 0),
                        rustle: CGSize(width: 2, height: -1),
                        settle: CGSize(width: 1, height: 0),
                        period: 6,
                        phase: 2
                    )
                )
            )
        case .unavailable:
            return TokenmonFieldVisualSpec(
                kind: self,
                palette: TokenmonFieldPalette(
                    baseShadow: Color.black.opacity(0.20),
                    baseMid: Color.gray.opacity(0.24),
                    baseHighlight: Color.white.opacity(0.18),
                    landmarkShade: Color.gray.opacity(0.16),
                    landmarkMain: Color.gray.opacity(0.32),
                    support: Color.gray.opacity(0.24),
                    motion: Color.white.opacity(0.20),
                    pocket: Color.black.opacity(0.08),
                    backplateFill: Color.black.opacity(0.22),
                    backplateStroke: Color.white.opacity(0.12)
                ),
                dominantCue: .neutral,
                supportAccent: .neutral,
                motionAccent: .none,
                spawnPocket: CGRect(x: 18, y: 6, width: 10, height: 5),
                effectOffset: .zero,
                landmarkOffset: CGPoint(x: 11, y: 3),
                supportOffset: CGPoint(x: 4, y: 9),
                motionOffset: CGPoint(x: 0, y: 0),
                motionProfile: TokenmonFieldMotionProfile(
                    landmark: TokenmonFieldMotionVector(
                        exploring: CGSize(width: 1, height: 0),
                        rustle: CGSize(width: 1, height: -1),
                        settle: CGSize(width: 0, height: 0),
                        period: 4,
                        phase: 0
                    ),
                    support: TokenmonFieldMotionVector(
                        exploring: CGSize(width: 0, height: 0),
                        rustle: CGSize(width: 0, height: 0),
                        settle: CGSize(width: 0, height: 0),
                        period: 4,
                        phase: 0
                    ),
                    accent: TokenmonFieldMotionVector(
                        exploring: .zero,
                        rustle: .zero,
                        settle: .zero,
                        period: 1,
                        phase: 0
                    )
                )
            )
        }
    }
}

struct TokenmonHabitatField: View {
    let spec: TokenmonFieldVisualSpec
    let sceneState: TokenmonSceneState
    let state: TokenmonFieldState
    let tick: Int
    let showsBackplate: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showsBackplate {
                backplateLayer
            }
            baseMassLayer
            landmarkLayer
            spawnPocketLayer
            spawnPulseLayer
            supportAccentLayer
            motionAccentLayer
        }
        .frame(width: 32, height: 16, alignment: .topLeading)
        .clipped()
    }

    private var backplateLayer: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        spec.palette.backplateStroke.opacity(0.45),
                        spec.palette.backplateFill,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(spec.palette.backplateStroke, lineWidth: 1)
            )
            .frame(width: 32, height: 16, alignment: .center)
            .offset(x: 0, y: 0)
    }

    private var baseMassLayer: some View {
        ZStack(alignment: .topLeading) {
            switch spec.dominantCue {
            case .meadowStage:
                EmptyView()

            case .iceFlurry:
                EmptyView()

            case .cloudShelf:
                EmptyView()

            case .shoreline:
                PixelSprite(dots: TokenmonPixelArt.simpleWaveBase(color: spec.palette.baseShadow), pixelSize: 1)
                    .offset(x: 0, y: 10)

            case .neutral:
                PixelSprite(dots: TokenmonPixelArt.windRibbon(color: spec.palette.landmarkMain), pixelSize: 1)
                    .offset(x: 8, y: 5)
            }
        }
    }

    private var landmarkLayer: some View {
        let motion = spec.motionProfile.landmark.offset(for: state, tick: tick)

        return ZStack(alignment: .topLeading) {
            switch spec.dominantCue {
            case .meadowStage:
                meadowTriplet

            case .iceFlurry:
                iceFlurry

            case .cloudShelf:
                skyCloudCluster

            case .shoreline:
                coastWave

            case .neutral:
                PixelSprite(dots: TokenmonPixelArt.windRibbon(color: spec.palette.baseHighlight), pixelSize: 1)
            }
        }
        .offset(
            x: spec.landmarkOffset.x + motion.width,
            y: spec.landmarkOffset.y + motion.height
        )
        .opacity(landmarkOpacity)
    }

    private var spawnPocketLayer: some View {
        PixelSprite(
            dots: TokenmonFieldPocketArt.pocketDots(color: spec.palette.pocket),
            pixelSize: 1
        )
        .offset(x: spec.spawnPocket.minX, y: spec.spawnPocket.minY)
        .opacity(spawnPocketOpacity)
    }

    private var spawnPulseLayer: some View {
        PixelSprite(
            dots: TokenmonFieldPocketArt.pulseDots(color: spec.palette.motion),
            pixelSize: 1
        )
        .offset(
            x: max(0, spec.spawnPocket.midX - 4),
            y: max(0, spec.spawnPocket.midY - 4)
        )
        .opacity(spawnPulseOpacity)
    }

    private var supportAccentLayer: some View {
        let motion = spec.motionProfile.support.offset(for: state, tick: tick)

        return ZStack(alignment: .topLeading) {
            switch spec.supportAccent {
            case .grasslandSprigs:
                PixelSprite(dots: TokenmonPixelArt.smallGrassTuft(color: spec.palette.support), pixelSize: 1)

            case .none:
                EmptyView()

            case .skyRibbon:
                PixelSprite(dots: TokenmonPixelArt.simpleSmallCloud(color: spec.palette.support), pixelSize: 1)

            case .coastDebris:
                PixelSprite(dots: TokenmonPixelArt.simpleWaveEcho(color: spec.palette.support), pixelSize: 1)

            case .iceCrystal:
                PixelSprite(dots: TokenmonPixelArt.simpleCrystalCluster(color: spec.palette.support), pixelSize: 1)
                PixelSprite(dots: TokenmonPixelArt.simpleCrystalGlow(color: spec.palette.motion), pixelSize: 1)
                    .offset(x: -1, y: 1)

            case .neutral:
                PixelSprite(dots: TokenmonPixelArt.oreVein(color: spec.palette.support), pixelSize: 1)
            }
        }
        .offset(
            x: spec.supportOffset.x + motion.width,
            y: spec.supportOffset.y + motion.height
        )
        .opacity(supportOpacity)
    }

    private var motionAccentLayer: some View {
        let motion = spec.motionProfile.accent.offset(for: state, tick: tick)

        return ZStack(alignment: .topLeading) {
            switch spec.motionAccent {
            case .pollen:
                PixelSprite(dots: TokenmonPixelArt.pollenTrail(color: spec.palette.motion), pixelSize: 1)

            case .windMotes:
                PixelSprite(dots: TokenmonPixelArt.windMote(color: spec.palette.motion), pixelSize: 1)
                PixelSprite(dots: TokenmonPixelArt.windMote(color: spec.palette.motion), pixelSize: 1)
                    .offset(x: 6, y: 2)
                PixelSprite(dots: TokenmonPixelArt.windMote(color: spec.palette.motion), pixelSize: 1)
                    .offset(x: 10, y: -1)

            case .seaSpray:
                PixelSprite(dots: TokenmonPixelArt.seaSpray(color: spec.palette.motion), pixelSize: 1)
                PixelSprite(dots: TokenmonPixelArt.seaSpray(color: spec.palette.motion), pixelSize: 1)
                    .offset(x: 4, y: 1)

            case .snowDrift:
                PixelSprite(dots: TokenmonPixelArt.windMote(color: spec.palette.motion), pixelSize: 1)
                PixelSprite(dots: TokenmonPixelArt.windMote(color: spec.palette.motion), pixelSize: 1)
                    .offset(x: 5, y: 1)
                PixelSprite(dots: TokenmonPixelArt.windMote(color: spec.palette.motion), pixelSize: 1)
                    .offset(x: 11, y: -1)

            case .dust:
                PixelSprite(dots: TokenmonPixelArt.cavePebbleTrail(color: spec.palette.motion), pixelSize: 1)
                PixelSprite(dots: TokenmonPixelArt.emberSpark(color: spec.palette.motion), pixelSize: 1)
                    .offset(x: 10, y: -3)

            case .none:
                EmptyView()
            }
        }
        .offset(
            x: spec.motionOffset.x + motion.width,
            y: spec.motionOffset.y + motion.height
        )
        .opacity(accentOpacity)
    }

    private var landmarkOpacity: Double {
        switch state {
        case .calm:
            return 0.90
        case .exploring:
            return 0.96
        case .rustle:
            return 1
        case .settle:
            return 0.84
        case .unavailable:
            return 0.48
        }
    }

    @ViewBuilder
    private var skyCloudCluster: some View {
        ZStack(alignment: .topLeading) {
            skyCloud(at: CGPoint(x: 0, y: 3), size: CGSize(width: 19, height: 12), drift: skyDrift(phase: 0))
            skyCloud(at: CGPoint(x: 11, y: 2), size: CGSize(width: 13, height: 9), drift: skyDrift(phase: 2))
            skyCloud(at: CGPoint(x: 21, y: 5), size: CGSize(width: 8, height: 6), drift: skyDrift(phase: 4))
        }
    }

    @ViewBuilder
    private func skyCloud(at origin: CGPoint, size: CGSize, drift: CGSize) -> some View {
        TokenmonFieldSpriteImage(field: .sky, variant: .skyCloud)
            .frame(width: size.width, height: size.height, alignment: .leading)
            .offset(x: origin.x + drift.width, y: origin.y + drift.height)
    }

    private func skyDrift(phase: Int) -> CGSize {
        switch state {
        case .calm, .unavailable:
            return .zero
        case .exploring:
            let pattern = [
                CGSize(width: 0, height: 0),
                CGSize(width: 2, height: -1),
                CGSize(width: 3, height: -1),
                CGSize(width: 2, height: 0),
                CGSize(width: 0, height: 0),
                CGSize(width: -2, height: 0),
            ]
            return pattern[(tick + phase) % pattern.count]
        case .rustle:
            let pattern = [
                CGSize(width: 2, height: -1),
                CGSize(width: 3, height: -1),
                CGSize(width: 2, height: -2),
                CGSize(width: 0, height: -1),
                CGSize(width: -2, height: -1),
                CGSize(width: -3, height: 0),
                CGSize(width: -2, height: 0),
                CGSize(width: 0, height: 0),
            ]
            return pattern[(tick + phase) % pattern.count]
        case .settle:
            let pattern = [
                CGSize(width: 0, height: 0),
                CGSize(width: 1, height: 0),
                CGSize(width: 0, height: 0),
                CGSize(width: -1, height: 0),
            ]
            return pattern[(tick + phase) % pattern.count]
        }
    }

    private var supportOpacity: Double {
        switch state {
        case .calm:
            return 0.74
        case .exploring:
            return 0.82
        case .rustle:
            return 0.92
        case .settle:
            return 0.70
        case .unavailable:
            return 0.40
        }
    }

    private var accentOpacity: Double {
        switch state {
        case .calm:
            return 0
        case .exploring:
            return 0.55
        case .rustle:
            return 0.84
        case .settle:
            return 0.32
        case .unavailable:
            return 0
        }
    }

    private var spawnPocketOpacity: Double {
        if sceneState == .spawn {
            return 0.34 + (Double(tick % 3) * 0.12)
        }

        switch state {
        case .calm:
            return 0.12
        case .exploring:
            return 0.16
        case .rustle:
            return 0.20
        case .settle:
            return 0.10
        case .unavailable:
            return 0.05
        }
    }

    private var spawnPulseOpacity: Double {
        switch sceneState {
        case .spawn:
            return [0.24, 0.42, 0.68, 0.46][tick % 4]
        case .alert:
            return 0.16
        default:
            return 0
        }
    }

    @ViewBuilder
    private var meadowTriplet: some View {
        ZStack(alignment: .topLeading) {
            meadowTuft(at: CGPoint(x: 1, y: 3), sway: meadowSway(phase: 0))
            meadowTuft(at: CGPoint(x: 10, y: 2), sway: meadowSway(phase: 1))
            meadowTuft(at: CGPoint(x: 19, y: 3), sway: meadowSway(phase: 2))
        }
    }

    @ViewBuilder
    private func meadowTuft(at origin: CGPoint, sway: CGSize) -> some View {
        TokenmonFieldSpriteImage(field: .grassland, variant: .grasslandTuft)
            .frame(width: 12, height: 9, alignment: .leading)
            .offset(x: origin.x + sway.width, y: origin.y + sway.height)
    }

    private func meadowSway(phase: Int) -> CGSize {
        switch state {
        case .calm, .unavailable:
            return .zero
        case .exploring:
            let pattern = [
                CGSize(width: 0, height: 0),
                CGSize(width: 2, height: -1),
                CGSize(width: 3, height: -1),
                CGSize(width: 2, height: 0),
                CGSize(width: 0, height: 0),
                CGSize(width: -2, height: 0),
            ]
            return pattern[(tick + phase) % pattern.count]
        case .rustle:
            let pattern = [
                CGSize(width: 2, height: -1),
                CGSize(width: 3, height: -2),
                CGSize(width: 2, height: -1),
                CGSize(width: 0, height: 0),
                CGSize(width: -2, height: -1),
                CGSize(width: -3, height: 0),
                CGSize(width: -2, height: 0),
                CGSize(width: 0, height: 0),
            ]
            return pattern[(tick + phase) % pattern.count]
        case .settle:
            let pattern = [
                CGSize(width: 1, height: 0),
                CGSize(width: 0, height: 0),
                CGSize(width: -1, height: 0),
                CGSize(width: 0, height: 0),
            ]
            return pattern[(tick + phase) % pattern.count]
        }
    }

    @ViewBuilder
    private var coastWave: some View {
        ZStack(alignment: .topLeading) {
            coastWaveSprite(at: CGPoint(x: 2, y: 5), size: CGSize(width: 11, height: 6), drift: coastDrift(phase: 0), opacity: 0.9)
            coastWaveSprite(at: CGPoint(x: 11, y: 3), size: CGSize(width: 19, height: 10), drift: coastDrift(phase: 3), opacity: 1.0)
        }
    }

    @ViewBuilder
    private func coastWaveSprite(at origin: CGPoint, size: CGSize, drift: CGSize, opacity: Double) -> some View {
        TokenmonFieldSpriteImage(field: .coast, variant: .coastWave)
            .frame(width: size.width, height: size.height, alignment: .leading)
            .offset(x: origin.x + drift.width, y: origin.y + drift.height)
            .opacity(opacity)
    }

    private func coastDrift(phase: Int) -> CGSize {
        switch state {
        case .calm, .unavailable:
            return .zero
        case .exploring:
            let pattern = [
                CGSize(width: 0, height: 0),
                CGSize(width: 2, height: 0),
                CGSize(width: 3, height: -1),
                CGSize(width: 2, height: 0),
                CGSize(width: 0, height: 0),
                CGSize(width: -2, height: 0),
            ]
            return pattern[(tick + phase) % pattern.count]
        case .rustle:
            let pattern = [
                CGSize(width: 2, height: 0),
                CGSize(width: 3, height: -1),
                CGSize(width: 2, height: -1),
                CGSize(width: 0, height: 0),
                CGSize(width: -2, height: 0),
                CGSize(width: -3, height: 0),
                CGSize(width: -2, height: 0),
                CGSize(width: 0, height: 0),
            ]
            return pattern[(tick + phase) % pattern.count]
        case .settle:
            let pattern = [
                CGSize(width: 1, height: 0),
                CGSize(width: 0, height: 0),
                CGSize(width: -1, height: 0),
                CGSize(width: 0, height: 0),
            ]
            return pattern[(tick + phase) % pattern.count]
        }
    }

    @ViewBuilder
    private var iceFlurry: some View {
        ZStack(alignment: .topLeading) {
            iceSnowflake(at: CGPoint(x: 2, y: 3), size: CGSize(width: 9, height: 9), drift: iceDrift(phase: 0))
            iceSnowflake(at: CGPoint(x: 12, y: 6), size: CGSize(width: 7, height: 7), drift: iceDrift(phase: 2))
            iceSnowflake(at: CGPoint(x: 20, y: 3), size: CGSize(width: 9, height: 9), drift: iceDrift(phase: 4))
        }
    }

    @ViewBuilder
    private func iceSnowflake(at origin: CGPoint, size: CGSize, drift: CGSize) -> some View {
        TokenmonFieldSpriteImage(field: .ice, variant: .iceSnowflake)
            .frame(width: size.width, height: size.height, alignment: .leading)
            .offset(x: origin.x + drift.width, y: origin.y + drift.height)
    }

    private func iceDrift(phase: Int) -> CGSize {
        switch state {
        case .calm, .unavailable:
            return .zero
        case .exploring:
            let pattern = [
                CGSize(width: 0, height: 0),
                CGSize(width: 2, height: 0),
                CGSize(width: 2, height: -1),
                CGSize(width: 0, height: -1),
                CGSize(width: -2, height: 0),
                CGSize(width: 0, height: 0),
            ]
            return pattern[(tick + phase) % pattern.count]
        case .rustle:
            let pattern = [
                CGSize(width: 2, height: -1),
                CGSize(width: 3, height: -1),
                CGSize(width: 2, height: -2),
                CGSize(width: 0, height: -1),
                CGSize(width: -2, height: 0),
                CGSize(width: -3, height: 0),
                CGSize(width: -2, height: 1),
                CGSize(width: 0, height: 0),
            ]
            return pattern[(tick + phase) % pattern.count]
        case .settle:
            let pattern = [
                CGSize(width: 0, height: 0),
                CGSize(width: 1, height: 0),
                CGSize(width: 0, height: 0),
                CGSize(width: -1, height: 0),
            ]
            return pattern[(tick + phase) % pattern.count]
        }
    }
}

private enum TokenmonFieldPocketArt {
    static func pocketDots(color: Color) -> [PixelDot] {
        let points = [
            (1, 0), (2, 0), (3, 0), (6, 0), (7, 0), (8, 0),
            (0, 1), (1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1), (7, 1), (8, 1), (9, 1),
            (0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2), (7, 2), (8, 2), (9, 2),
            (0, 3), (1, 3), (2, 3), (3, 3), (6, 3), (7, 3), (8, 3), (9, 3),
            (1, 4), (2, 4), (3, 4), (6, 4), (7, 4), (8, 4),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func pulseDots(color: Color) -> [PixelDot] {
        let points = [
            (2, 0), (5, 0),
            (1, 1), (6, 1),
            (0, 2), (7, 2),
            (0, 5), (7, 5),
            (1, 6), (6, 6),
            (2, 7), (5, 7),
            (2, 2), (5, 2),
            (2, 5), (5, 5),
            (3, 3), (4, 3),
            (3, 4), (4, 4),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }
}
