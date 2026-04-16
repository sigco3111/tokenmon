import SwiftUI
import TokenmonPersistence

struct TokenmonPopoverContainerActions {
    let openFullDex: () -> Void
    let openSettings: (TokenmonSettingsPane) -> Void
    let openDeveloperTools: (() -> Void)?
    let quit: () -> Void
    let selectSpecies: (DexEntrySummary) -> Void
}

struct TokenmonPopoverContainer: View {
    @ObservedObject var model: TokenmonMenuModel
    let actions: TokenmonPopoverContainerActions

    @State private var activeTab: TokenmonPopoverTab = .now

    init(
        model: TokenmonMenuModel,
        actions: TokenmonPopoverContainerActions,
        initialActiveTab: TokenmonPopoverTab = .now
    ) {
        self.model = model
        self.actions = actions
        _activeTab = State(initialValue: initialActiveTab)
    }

    static func refreshSurfaceForActivation(
        activeTab: TokenmonPopoverTab,
        runtimeLoaded: Bool
    ) -> TokenmonRefreshSurface? {
        switch activeTab {
        case .now:
            return runtimeLoaded ? nil : .now
        case .tokens:
            return .tokens
        case .stats:
            return .stats
        case .dex:
            return .dex
        }
    }

    static func analyticsSurface(for activeTab: TokenmonPopoverTab) -> TokenmonRefreshSurface {
        switch activeTab {
        case .now:
            return .now
        case .tokens:
            return .tokens
        case .stats:
            return .stats
        case .dex:
            return .dex
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            content
                .frame(width: 300, height: 480, alignment: .topLeading)

            Divider()

            TokenmonPopoverSidebar(
                activeTab: $activeTab,
                actions: TokenmonPopoverSidebarActions(
                    openSettings: { actions.openSettings(.general) },
                    quit: actions.quit,
                    openDeveloperTools: actions.openDeveloperTools
                )
            )
        }
        .frame(width: 360, height: 480)
        .onAppear {
            prewarmActiveTabIfNeeded()
        }
        .onChange(of: activeTab) { _, _ in
            prewarmActiveTabIfNeeded()
        }
        .background(
            // Hidden hotkey buttons for ⌘1 / ⌘2 / ⌘3 / ⌘4
            HStack {
                Button(TokenmonL10n.string("popover.tab.now")) { activeTab = .now }
                    .keyboardShortcut("1", modifiers: [.command])
                Button(TokenmonL10n.string("popover.tab.tokens")) { activeTab = .tokens }
                    .keyboardShortcut("2", modifiers: [.command])
                Button(TokenmonL10n.string("popover.tab.stats")) { activeTab = .stats }
                    .keyboardShortcut("3", modifiers: [.command])
                Button(TokenmonL10n.string("window.title.dex")) { activeTab = .dex }
                    .keyboardShortcut("4", modifiers: [.command])
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch activeTab {
        case .now:
            TokenmonNowTab(
                model: model,
                onOpenProviderSettings: { actions.openSettings(.providers) }
            )
        case .stats:
            TokenmonStatsTab(model: model)
        case .dex:
            TokenmonDexTab(
                model: model,
                onOpenFullDex: actions.openFullDex,
                onSelectSpecies: actions.selectSpecies
            )
        case .tokens:
            TokenmonTokensTab(model: model)
        }
    }

    private func prewarmActiveTabIfNeeded() {
        let surface = Self.analyticsSurface(for: activeTab)
        let shouldRefresh = Self.refreshSurfaceForActivation(
            activeTab: activeTab,
            runtimeLoaded: model.runtimeSnapshot.isLoaded
        ) != nil

        model.surfaceOpened(
            surface,
            entrypoint: "popover_tab",
            refresh: shouldRefresh
        )
    }
}
