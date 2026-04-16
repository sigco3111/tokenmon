import SwiftUI
import TokenmonDomain
import TokenmonPersistence

extension AppLanguagePreference {
    var displayName: String {
        switch self {
        case .system:
            return TokenmonL10n.string("settings.language.option.system")
        case .english:
            return TokenmonL10n.activeLocale.localizedString(forIdentifier: "en") ?? TokenmonL10n.string("settings.language.option.english")
        case .korean:
            return TokenmonL10n.activeLocale.localizedString(forIdentifier: "ko") ?? TokenmonL10n.string("settings.language.option.korean")
        }
    }
}

extension AppAppearancePreference {
    var displayName: String {
        switch self {
        case .system:
            return TokenmonL10n.string("settings.appearance.option.system")
        case .light:
            return TokenmonL10n.string("settings.appearance.option.light")
        case .dark:
            return TokenmonL10n.string("settings.appearance.option.dark")
        }
    }
}

extension FieldType {
    var displayName: String {
        switch self {
        case .grassland:
            return TokenmonL10n.string("field.grassland")
        case .ice:
            return TokenmonL10n.string("field.ice")
        case .coast:
            return TokenmonL10n.string("field.coast")
        case .sky:
            return TokenmonL10n.string("field.sky")
        }
    }

    var systemImage: String {
        switch self {
        case .grassland:
            return "leaf.fill"
        case .ice:
            return "snowflake"
        case .coast:
            return "water.waves"
        case .sky:
            return "wind"
        }
    }

    var tint: Color {
        switch self {
        case .grassland:
            return Color(red: 0.27, green: 0.63, blue: 0.35)
        case .ice:
            return Color(red: 0.44, green: 0.72, blue: 0.96)
        case .coast:
            return Color(red: 0.17, green: 0.54, blue: 0.79)
        case .sky:
            return Color(red: 0.29, green: 0.54, blue: 0.88)
        }
    }
}

extension RarityTier {
    var displayName: String {
        switch self {
        case .common:
            return TokenmonL10n.string("rarity.common")
        case .uncommon:
            return TokenmonL10n.string("rarity.uncommon")
        case .rare:
            return TokenmonL10n.string("rarity.rare")
        case .epic:
            return TokenmonL10n.string("rarity.epic")
        case .legendary:
            return TokenmonL10n.string("rarity.legendary")
        }
    }

    var systemImage: String {
        switch self {
        case .common:
            return "circle.fill"
        case .uncommon:
            return "diamond.fill"
        case .rare:
            return "triangle.fill"
        case .epic:
            return "sparkles"
        case .legendary:
            return "crown.fill"
        }
    }

    var tint: Color {
        switch self {
        case .common:
            return .secondary
        case .uncommon:
            return Color(red: 0.28, green: 0.63, blue: 0.41)
        case .rare:
            return Color(red: 0.22, green: 0.48, blue: 0.86)
        case .epic:
            return Color(red: 0.71, green: 0.35, blue: 0.86)
        case .legendary:
            return Color(red: 0.92, green: 0.67, blue: 0.14)
        }
    }
}

extension EncounterOutcome {
    var displayName: String {
        switch self {
        case .captured:
            return TokenmonL10n.string("outcome.captured")
        case .escaped:
            return TokenmonL10n.string("outcome.escaped")
        }
    }
}

extension DexEntryStatus {
    var detailTitle: String {
        switch self {
        case .captured:
            return TokenmonL10n.string("dex.status.captured")
        case .seenUncaptured:
            return TokenmonL10n.string("dex.status.seen")
        case .unknown:
            return TokenmonL10n.string("dex.status.hidden")
        }
    }

    var systemImage: String {
        switch self {
        case .captured:
            return "checkmark.seal.fill"
        case .seenUncaptured:
            return "eye.fill"
        case .unknown:
            return "lock.fill"
        }
    }

    var tint: Color {
        switch self {
        case .captured:
            return .green
        case .seenUncaptured:
            return .orange
        case .unknown:
            return .secondary
        }
    }
}

extension TokenmonSceneFieldKind {
    var debugFieldType: FieldType {
        switch self {
        case .grassland:
            return .grassland
        case .ice:
            return .ice
        case .coast:
            return .coast
        case .sky:
            return .sky
        case .unavailable:
            return .grassland
        }
    }

    var heroFieldType: FieldType {
        switch self {
        case .grassland:
            return .grassland
        case .ice:
            return .ice
        case .coast:
            return .coast
        case .sky, .unavailable:
            return .sky
        }
    }

    var localizedTitle: String {
        switch self {
        case .grassland:
            return FieldType.grassland.displayName
        case .ice:
            return FieldType.ice.displayName
        case .coast:
            return FieldType.coast.displayName
        case .sky:
            return FieldType.sky.displayName
        case .unavailable:
            return TokenmonL10n.string("field.unavailable")
        }
    }

    var debugTitle: String { localizedTitle }
    var heroFieldTitle: String { localizedTitle }
    var previewTitle: String { localizedTitle }

    var systemImage: String {
        switch self {
        case .grassland:
            return "leaf.fill"
        case .ice:
            return "snowflake"
        case .coast:
            return "water.waves"
        case .sky:
            return "wind"
        case .unavailable:
            return "questionmark.circle"
        }
    }

    var heroFieldSystemImage: String { systemImage }
}
