import SwiftUI
import TokenmonDomain

struct TokenmonDexAlbumStyle: Equatable {
    let emphasisLevel: Int
    let rarityLabel: String
    let primarySymbol: String
    let borderOpacity: Double
    let glowOpacity: Double
    let rarityFillOpacity: Double

    static func make(for rarity: RarityTier) -> TokenmonDexAlbumStyle {
        switch rarity {
        case .common:
            return TokenmonDexAlbumStyle(
                emphasisLevel: 0,
                rarityLabel: "Common",
                primarySymbol: "circle.fill",
                borderOpacity: 0.16,
                glowOpacity: 0.00,
                rarityFillOpacity: 0.03
            )
        case .uncommon:
            return TokenmonDexAlbumStyle(
                emphasisLevel: 1,
                rarityLabel: "Uncommon",
                primarySymbol: "diamond.fill",
                borderOpacity: 0.22,
                glowOpacity: 0.04,
                rarityFillOpacity: 0.05
            )
        case .rare:
            return TokenmonDexAlbumStyle(
                emphasisLevel: 2,
                rarityLabel: "Rare",
                primarySymbol: "triangle.fill",
                borderOpacity: 0.30,
                glowOpacity: 0.07,
                rarityFillOpacity: 0.08
            )
        case .epic:
            return TokenmonDexAlbumStyle(
                emphasisLevel: 3,
                rarityLabel: "Epic",
                primarySymbol: "sparkles",
                borderOpacity: 0.40,
                glowOpacity: 0.06,
                rarityFillOpacity: 0.12
            )
        case .legendary:
            return TokenmonDexAlbumStyle(
                emphasisLevel: 4,
                rarityLabel: "Legendary",
                primarySymbol: "crown.fill",
                borderOpacity: 0.50,
                glowOpacity: 0.09,
                rarityFillOpacity: 0.16
            )
        }
    }
}
