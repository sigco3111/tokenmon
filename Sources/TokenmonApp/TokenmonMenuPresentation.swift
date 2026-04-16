import Foundation
import TokenmonDomain
import TokenmonPersistence

enum TokenmonSettingsPane: String, CaseIterable, Hashable {
    case general
    case providers

    var title: String {
        switch self {
        case .general:
            return TokenmonL10n.string("settings.pane.general.title")
        case .providers:
            return TokenmonL10n.string("settings.pane.providers.title")
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "gearshape"
        case .providers:
            return "link.badge.plus"
        }
    }
}

struct TokenmonMenuSnapshot {
    let summary: CurrentRunSummary?
    let latestEncounter: RecentEncounterSummary?
    let providerHealthSummaries: [ProviderHealthSummary]
    let onboardingStatuses: [TokenmonProviderOnboardingStatus]
    let loadError: String?
}

struct TokenmonMenuPresentation: Equatable {
    let headline: String
    let detail: String?
    let statsLine: String?
    let latestEncounterTitle: String
    let latestEncounterDetail: String?
    let providerSummary: String?
}

enum TokenmonMenuPresentationBuilder {
    private static let recentEncounterHighlightTokenWindow: Int64 = 400
    private static let imminentEncounterTokenWindow: Int64 = 200
    private static let nearEncounterTokenWindow: Int64 = 600

    /// Headline pools picked deterministically by `totalEncounters` so the
    /// chosen phrase is stable within an encounter cycle but varies across
    /// cycles, giving the popover some narrative flavor without flicker.
    /// Each tier has a generic pool plus per-field flavor pools, so the
    /// copy reflects the current map (grassland / ice / coast / sky).

    static let imminentHeadlines: [StaticString] = [
        "menu.headline.imminent.1",
        "menu.headline.imminent.2",
        "menu.headline.imminent.3",
        "menu.headline.imminent.4",
        "menu.headline.imminent.5",
    ]
    static let imminentHeadlinesGrassland: [StaticString] = [
        "menu.headline.imminent.grassland.1",
        "menu.headline.imminent.grassland.2",
        "menu.headline.imminent.grassland.3",
        "menu.headline.imminent.grassland.4",
    ]
    static let imminentHeadlinesIce: [StaticString] = [
        "menu.headline.imminent.ice.1",
        "menu.headline.imminent.ice.2",
        "menu.headline.imminent.ice.3",
        "menu.headline.imminent.ice.4",
    ]
    static let imminentHeadlinesCoast: [StaticString] = [
        "menu.headline.imminent.coast.1",
        "menu.headline.imminent.coast.2",
        "menu.headline.imminent.coast.3",
        "menu.headline.imminent.coast.4",
    ]
    static let imminentHeadlinesSky: [StaticString] = [
        "menu.headline.imminent.sky.1",
        "menu.headline.imminent.sky.2",
        "menu.headline.imminent.sky.3",
        "menu.headline.imminent.sky.4",
    ]

    static let rustlingHeadlines: [StaticString] = [
        "menu.headline.rustle.1",
        "menu.headline.rustle.2",
        "menu.headline.rustle.3",
        "menu.headline.rustle.4",
        "menu.headline.rustle.5",
    ]
    static let rustlingHeadlinesGrassland: [StaticString] = [
        "menu.headline.rustle.grassland.1",
        "menu.headline.rustle.grassland.2",
        "menu.headline.rustle.grassland.3",
        "menu.headline.rustle.grassland.4",
    ]
    static let rustlingHeadlinesIce: [StaticString] = [
        "menu.headline.rustle.ice.1",
        "menu.headline.rustle.ice.2",
        "menu.headline.rustle.ice.3",
        "menu.headline.rustle.ice.4",
    ]
    static let rustlingHeadlinesCoast: [StaticString] = [
        "menu.headline.rustle.coast.1",
        "menu.headline.rustle.coast.2",
        "menu.headline.rustle.coast.3",
        "menu.headline.rustle.coast.4",
    ]
    static let rustlingHeadlinesSky: [StaticString] = [
        "menu.headline.rustle.sky.1",
        "menu.headline.rustle.sky.2",
        "menu.headline.rustle.sky.3",
        "menu.headline.rustle.sky.4",
    ]

    static let exploringHeadlines: [StaticString] = [
        "menu.headline.exploring.1",
        "menu.headline.exploring.2",
        "menu.headline.exploring.3",
        "menu.headline.exploring.4",
        "menu.headline.exploring.5",
        "menu.headline.exploring.6",
    ]
    static let exploringHeadlinesGrassland: [StaticString] = [
        "menu.headline.exploring.grassland.1",
        "menu.headline.exploring.grassland.2",
        "menu.headline.exploring.grassland.3",
        "menu.headline.exploring.grassland.4",
    ]
    static let exploringHeadlinesIce: [StaticString] = [
        "menu.headline.exploring.ice.1",
        "menu.headline.exploring.ice.2",
        "menu.headline.exploring.ice.3",
        "menu.headline.exploring.ice.4",
    ]
    static let exploringHeadlinesCoast: [StaticString] = [
        "menu.headline.exploring.coast.1",
        "menu.headline.exploring.coast.2",
        "menu.headline.exploring.coast.3",
        "menu.headline.exploring.coast.4",
    ]
    static let exploringHeadlinesSky: [StaticString] = [
        "menu.headline.exploring.sky.1",
        "menu.headline.exploring.sky.2",
        "menu.headline.exploring.sky.3",
        "menu.headline.exploring.sky.4",
    ]

    static func build(
        snapshot: TokenmonMenuSnapshot,
        providerStatusVisible: Bool
    ) -> TokenmonMenuPresentation {
        let latestEncounterTitle: String
        let latestEncounterDetail: String?
        if let latestEncounter = snapshot.latestEncounter {
            latestEncounterTitle = TokenmonDexPresentation.visibleSpeciesName(for: latestEncounter, style: .sentence)
            latestEncounterDetail = encounterDetail(latestEncounter)
        } else {
            latestEncounterTitle = TokenmonL10n.string("menu.latest.no_encounters")
            latestEncounterDetail = nil
        }

        if let loadError = snapshot.loadError {
            return TokenmonMenuPresentation(
                headline: TokenmonL10n.string("menu.headline.unavailable"),
                detail: loadError,
                statsLine: nil,
                latestEncounterTitle: latestEncounterTitle,
                latestEncounterDetail: latestEncounterDetail,
                providerSummary: nil
            )
        }

        guard let summary = snapshot.summary else {
            return TokenmonMenuPresentation(
                headline: TokenmonL10n.string("menu.headline.loading"),
                detail: TokenmonL10n.string("menu.detail.refreshing"),
                statsLine: nil,
                latestEncounterTitle: latestEncounterTitle,
                latestEncounterDetail: latestEncounterDetail,
                providerSummary: nil
            )
        }

        let statsLine = TokenmonL10n.format(
            "menu.stats.line",
            summary.totalEncounters,
            summary.totalCaptures,
            summary.seenSpeciesCount
        )

        if let latestEncounter = snapshot.latestEncounter, summary.tokensSinceLastEncounter <= recentEncounterHighlightTokenWindow {
            let displayName = TokenmonDexPresentation.visibleSpeciesName(for: latestEncounter, style: .sentence)
            let headline = latestEncounter.outcome == .captured
                ? TokenmonL10n.format("menu.headline.captured", displayName)
                : TokenmonL10n.format("menu.headline.escaped", displayName)
            let toneLine = TokenmonL10n.format(
                "menu.latest.tone_line",
                latestEncounter.rarity.displayName,
                latestEncounter.field.displayName
            )

            return TokenmonMenuPresentation(
                headline: headline,
                detail: nil,
                statsLine: toneLine,
                latestEncounterTitle: latestEncounterTitle,
                latestEncounterDetail: latestEncounterDetail,
                providerSummary: providerSummary(
                    providerHealthSummaries: snapshot.providerHealthSummaries,
                    providerStatusVisible: providerStatusVisible
                )
            )
        }

        if summary.totalNormalizedTokens == 0 {
            return TokenmonMenuPresentation(
                headline: TokenmonL10n.string("menu.headline.waiting"),
                detail: TokenmonL10n.string("menu.detail.start_exploring"),
                statsLine: statsLine,
                latestEncounterTitle: latestEncounterTitle,
                latestEncounterDetail: latestEncounterDetail,
                providerSummary: providerSummary(
                    providerHealthSummaries: snapshot.providerHealthSummaries,
                    providerStatusVisible: providerStatusVisible
                )
            )
        }

        let headline = progressHeadline(
            tokensUntilNextEncounter: summary.tokensUntilNextEncounter,
            totalEncounters: summary.totalEncounters,
            field: snapshot.latestEncounter?.field
        )

        return TokenmonMenuPresentation(
            headline: headline,
            detail: nil,
            statsLine: statsLine,
            latestEncounterTitle: latestEncounterTitle,
            latestEncounterDetail: latestEncounterDetail,
            providerSummary: providerSummary(
                providerHealthSummaries: snapshot.providerHealthSummaries,
                providerStatusVisible: providerStatusVisible
            )
        )
    }

    static func progressHeadline(
        tokensUntilNextEncounter: Int64,
        totalEncounters: Int64,
        field: FieldType? = nil
    ) -> String {
        let pool = headlinePool(tokensUntilNextEncounter: tokensUntilNextEncounter, field: field)
        let seed = max(0, Int(totalEncounters))
        return TokenmonL10n.string(pool[seed % pool.count])
    }

    private static func headlinePool(
        tokensUntilNextEncounter: Int64,
        field: FieldType?
    ) -> [StaticString] {
        if tokensUntilNextEncounter <= imminentEncounterTokenWindow {
            switch field {
            case .grassland: return imminentHeadlinesGrassland
            case .ice: return imminentHeadlinesIce
            case .coast: return imminentHeadlinesCoast
            case .sky: return imminentHeadlinesSky
            case nil: return imminentHeadlines
            }
        } else if tokensUntilNextEncounter <= nearEncounterTokenWindow {
            switch field {
            case .grassland: return rustlingHeadlinesGrassland
            case .ice: return rustlingHeadlinesIce
            case .coast: return rustlingHeadlinesCoast
            case .sky: return rustlingHeadlinesSky
            case nil: return rustlingHeadlines
            }
        } else {
            switch field {
            case .grassland: return exploringHeadlinesGrassland
            case .ice: return exploringHeadlinesIce
            case .coast: return exploringHeadlinesCoast
            case .sky: return exploringHeadlinesSky
            case nil: return exploringHeadlines
            }
        }
    }

    private static func providerSummary(
        providerHealthSummaries: [ProviderHealthSummary],
        providerStatusVisible: Bool
    ) -> String? {
        guard providerStatusVisible else {
            return nil
        }
        guard providerHealthSummaries.isEmpty == false else {
            return nil
        }

        let activeCount = providerHealthSummaries.filter {
            $0.healthState == "active" || $0.healthState == "connected"
        }.count

        if activeCount == providerHealthSummaries.count {
            return TokenmonL10n.format(
                activeCount == 1 ? "menu.provider_summary.ready.one" : "menu.provider_summary.ready.other",
                activeCount
            )
        }

        if activeCount > 0 {
            return TokenmonL10n.format(
                "menu.provider_summary.partial",
                activeCount,
                providerHealthSummaries.count
            )
        }

        return TokenmonL10n.string("menu.provider_summary.settings")
    }

    private static func encounterDetail(_ encounter: RecentEncounterSummary) -> String {
        TokenmonL10n.format(
            "menu.latest.detail",
            encounter.rarity.displayName,
            encounter.field.displayName,
            encounter.outcome.displayName
        )
    }
}
