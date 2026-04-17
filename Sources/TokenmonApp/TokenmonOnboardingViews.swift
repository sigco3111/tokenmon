import Foundation
import SwiftUI
import TokenmonPersistence

enum TokenmonSetupRecommendationAction: Equatable, Sendable {
    case enableLaunchAtLogin
    case openLoginItemsSettings
    case enableCaptureNotifications
    case requestCaptureNotificationPermission
    case openNotificationSettings
}

enum TokenmonSetupRecommendationTint: Equatable, Sendable {
    case secondary
    case green
    case orange
    case red

    @MainActor
    var color: Color {
        switch self {
        case .secondary:
            return .secondary
        case .green:
            return .green
        case .orange:
            return .orange
        case .red:
            return .red
        }
    }
}

struct TokenmonSetupRecommendationItem: Equatable, Sendable {
    let title: String
    let detail: String
    let systemImage: String
    let tint: TokenmonSetupRecommendationTint
    let actionTitle: String?
    let action: TokenmonSetupRecommendationAction?
}

enum TokenmonSetupRecommendationsBuilder {
    static func items(
        appSettings: AppSettings,
        launchAtLoginState: TokenmonLaunchAtLoginState,
        notificationAuthorizationState: TokenmonNotificationAuthorizationState
    ) -> [TokenmonSetupRecommendationItem] {
        var results: [TokenmonSetupRecommendationItem] = []

        if let launchRecommendation = launchRecommendation(for: launchAtLoginState) {
            results.append(launchRecommendation)
        }

        if let notificationRecommendation = notificationRecommendation(
            appSettings: appSettings,
            authorizationState: notificationAuthorizationState
        ) {
            results.append(notificationRecommendation)
        }

        return results
    }

    static func launchStatusSymbol(_ state: TokenmonLaunchAtLoginState) -> String {
        if state.isSupported == false {
            return "exclamationmark.triangle.fill"
        }

        return state.isEnabled ? "checkmark.circle.fill" : "info.circle.fill"
    }

    static func launchStatusTint(_ state: TokenmonLaunchAtLoginState) -> TokenmonSetupRecommendationTint {
        if state.isSupported == false {
            return .orange
        }

        return state.isEnabled ? .green : .secondary
    }

    static func notificationAuthorizationDetail(_ state: TokenmonNotificationAuthorizationState) -> String {
        switch state {
        case .unknown:
            return TokenmonL10n.string("settings.notifications.status.checking")
        case .notDetermined:
            return TokenmonL10n.string("settings.notifications.status.not_determined")
        case .denied:
            return TokenmonL10n.string("settings.notifications.status.denied")
        case .authorized(let alertsEnabled, let soundsEnabled, let alertStyle):
            if alertsEnabled {
                let styleSummary: String
                switch alertStyle {
                case 0:
                    styleSummary = TokenmonL10n.string("settings.notifications.style.none")
                case 1:
                    styleSummary = TokenmonL10n.string("settings.notifications.style.banners")
                case 2:
                    styleSummary = TokenmonL10n.string("settings.notifications.style.alerts")
                default:
                    styleSummary = TokenmonL10n.string("settings.notifications.style.unknown")
                }
                return soundsEnabled
                    ? TokenmonL10n.format("settings.notifications.status.authorized_with_sound", styleSummary)
                    : TokenmonL10n.format("settings.notifications.status.authorized_without_sound", styleSummary)
            }
            return TokenmonL10n.string("settings.notifications.status.alerts_disabled")
        }
    }

    static func notificationAuthorizationSymbol(_ state: TokenmonNotificationAuthorizationState) -> String {
        switch state {
        case .unknown:
            return "hourglass"
        case .notDetermined:
            return "questionmark.circle.fill"
        case .denied:
            return "bell.slash.fill"
        case .authorized(let alertsEnabled, _, _):
            return alertsEnabled ? "checkmark.circle.fill" : "bell.badge.slash.fill"
        }
    }

    static func notificationAuthorizationTint(_ state: TokenmonNotificationAuthorizationState) -> TokenmonSetupRecommendationTint {
        switch state {
        case .unknown:
            return .secondary
        case .notDetermined:
            return .orange
        case .denied:
            return .red
        case .authorized(let alertsEnabled, _, _):
            return alertsEnabled ? .green : .orange
        }
    }

    private static func launchRecommendation(
        for state: TokenmonLaunchAtLoginState
    ) -> TokenmonSetupRecommendationItem? {
        let action: TokenmonSetupRecommendationAction?
        let actionTitle: String?

        if state.isSupported, state.isEnabled == false, state.showsOpenSystemSettingsAction == false {
            action = .enableLaunchAtLogin
            actionTitle = TokenmonL10n.string("settings.general.quick_setup.action.enable_launch_at_login")
        } else if state.showsOpenSystemSettingsAction {
            action = .openLoginItemsSettings
            actionTitle = TokenmonL10n.string("settings.general.open_login_items_settings")
        } else {
            action = nil
            actionTitle = nil
        }

        guard let action else {
            return nil
        }

        return TokenmonSetupRecommendationItem(
            title: TokenmonL10n.string("settings.general.quick_setup.launch_title"),
            detail: state.reason,
            systemImage: launchStatusSymbol(state),
            tint: launchStatusTint(state),
            actionTitle: actionTitle,
            action: action
        )
    }

    private static func notificationRecommendation(
        appSettings: AppSettings,
        authorizationState: TokenmonNotificationAuthorizationState
    ) -> TokenmonSetupRecommendationItem? {
        let detail: String
        let actionTitle: String?
        let action: TokenmonSetupRecommendationAction?

        if appSettings.notificationsEnabled == false {
            detail = notificationAuthorizationDetail(authorizationState)
            actionTitle = TokenmonL10n.string("settings.general.quick_setup.action.enable_capture_notifications")
            action = .enableCaptureNotifications
        } else {
            switch authorizationState {
            case .unknown:
                detail = notificationAuthorizationDetail(authorizationState)
                actionTitle = nil
                action = nil
            case .notDetermined:
                detail = notificationAuthorizationDetail(authorizationState)
                actionTitle = TokenmonL10n.string("settings.general.quick_setup.action.request_notification_permission")
                action = .requestCaptureNotificationPermission
            case .denied:
                detail = notificationAuthorizationDetail(authorizationState)
                actionTitle = TokenmonL10n.string("settings.general.open_notification_settings")
                action = .openNotificationSettings
            case .authorized(let alertsEnabled, _, _):
                if alertsEnabled {
                    detail = TokenmonL10n.string("settings.general.quick_setup.notifications.preference_off")
                    actionTitle = nil
                    action = nil
                } else {
                    detail = notificationAuthorizationDetail(authorizationState)
                    actionTitle = TokenmonL10n.string("settings.general.open_notification_settings")
                    action = .openNotificationSettings
                }
            }
        }

        guard appSettings.notificationsEnabled == false || action != nil else {
            return nil
        }

        return TokenmonSetupRecommendationItem(
            title: TokenmonL10n.string("settings.general.quick_setup.notifications_title"),
            detail: detail,
            systemImage: notificationAuthorizationSymbol(authorizationState),
            tint: notificationAuthorizationTint(authorizationState),
            actionTitle: actionTitle,
            action: action
        )
    }
}

struct TokenmonSetupRecommendationList: View {
    let items: [TokenmonSetupRecommendationItem]
    let onPerformAction: (TokenmonSetupRecommendationAction) -> Void

    var body: some View {
        if items.isEmpty {
            Label {
                Text(TokenmonL10n.string("settings.general.quick_setup.complete"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    TokenmonSetupRecommendationRow(item: item, onPerformAction: onPerformAction)
                }
            }
        }
    }
}

private struct TokenmonSetupRecommendationRow: View {
    let item: TokenmonSetupRecommendationItem
    let onPerformAction: (TokenmonSetupRecommendationAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: item.systemImage)
                    .foregroundStyle(item.tint.color)
            }

            Text(item.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let actionTitle = item.actionTitle,
               let action = item.action {
                Button(actionTitle) {
                    onPerformAction(action)
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
    }
}

enum TokenmonFirstRunOnboardingStep: Int, CaseIterable, Sendable {
    case welcome
    case permissions
    case providers

    var title: String {
        switch self {
        case .welcome:
            return TokenmonL10n.string("onboarding.welcome.title")
        case .permissions:
            return TokenmonL10n.string("onboarding.permissions.title")
        case .providers:
            return TokenmonL10n.string("onboarding.providers.title")
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            return TokenmonL10n.string("onboarding.welcome.subtitle")
        case .permissions:
            return TokenmonL10n.string("onboarding.permissions.subtitle")
        case .providers:
            return TokenmonL10n.string("onboarding.providers.subtitle")
        }
    }

    var index: Int { rawValue + 1 }

    var previous: TokenmonFirstRunOnboardingStep? {
        guard rawValue > 0 else {
            return nil
        }

        return TokenmonFirstRunOnboardingStep(rawValue: rawValue - 1)
    }

    var next: TokenmonFirstRunOnboardingStep? {
        TokenmonFirstRunOnboardingStep(rawValue: rawValue + 1)
    }
}

struct TokenmonOnboardingPanel: View {
    @ObservedObject var model: TokenmonMenuModel
    @State private var currentStep: TokenmonFirstRunOnboardingStep = .welcome

    let onPerformSetupAction: (TokenmonSetupRecommendationAction) -> Void
    let onOpenProvidersSettings: () -> Void
    let onSkip: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            TokenmonSettingsPaneHeader(
                title: currentStep.title,
                subtitle: currentStep.subtitle
            )

            TokenmonOnboardingProgressView(currentStep: currentStep)

            TokenmonSettingsBanner(
                banner: TokenmonSettingsPresentationBuilder.banner(
                    message: model.settingsMessage,
                    error: model.settingsError
                )
            )

            Group {
                switch currentStep {
                case .welcome:
                    TokenmonOnboardingWelcomeStep()
                case .permissions:
                    TokenmonOnboardingPermissionsStep(
                        appSettings: model.appSettings,
                        launchAtLoginState: model.launchAtLoginState,
                        notificationAuthorizationState: model.notificationAuthorizationState,
                        onPerformSetupAction: onPerformSetupAction
                    )
                case .providers:
                    TokenmonOnboardingProvidersStep(
                        onboardingStatuses: model.onboardingStatuses,
                        providerHealthSummaries: model.providerHealthSummaries
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            footer
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 620, alignment: .topLeading)
        .environment(\.locale, TokenmonL10n.activeLocale)
        .onAppear {
            model.surfaceOpened(.onboarding, entrypoint: "window_content", emitAnalytics: false)
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch currentStep {
        case .welcome:
            HStack {
                Button(TokenmonL10n.string("onboarding.action.skip")) {
                    onSkip()
                }
                .buttonStyle(.glass)

                Spacer()

                Button(TokenmonL10n.string("onboarding.action.continue")) {
                    currentStep = .permissions
                }
                .buttonStyle(.glassProminent)
            }
        case .permissions:
            HStack {
                Button(TokenmonL10n.string("common.back")) {
                    currentStep = .welcome
                }
                .buttonStyle(.glass)

                Spacer()

                Button(TokenmonL10n.string("onboarding.action.skip")) {
                    onSkip()
                }
                .buttonStyle(.glass)

                Button(TokenmonL10n.string("onboarding.action.continue")) {
                    currentStep = .providers
                }
                .buttonStyle(.glassProminent)
            }
        case .providers:
            HStack {
                Button(TokenmonL10n.string("common.back")) {
                    currentStep = .permissions
                }
                .buttonStyle(.glass)

                Spacer()

                Button(TokenmonL10n.string("onboarding.providers.open_settings")) {
                    onOpenProvidersSettings()
                }
                .buttonStyle(.glass)

                Button(TokenmonL10n.string("onboarding.action.finish")) {
                    onFinish()
                }
                .buttonStyle(.glassProminent)
            }
        }
    }
}

private struct TokenmonOnboardingProgressView: View {
    let currentStep: TokenmonFirstRunOnboardingStep

    var body: some View {
        HStack(spacing: 12) {
            ForEach(TokenmonFirstRunOnboardingStep.allCases, id: \.self) { step in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(width: 10, height: 10)
                        Text(step.title)
                            .font(.caption.weight(step == currentStep ? .semibold : .regular))
                    }

                    Rectangle()
                        .fill(step == .providers ? Color.clear : step.rawValue < currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.15))
                        .frame(height: 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct TokenmonOnboardingWelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TokenmonSettingsSectionCard(
                title: TokenmonL10n.string("onboarding.welcome.section_title"),
                systemImage: "sparkles"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(TokenmonL10n.string("onboarding.welcome.body"))
                        .font(.body)

                    VStack(alignment: .leading, spacing: 8) {
                        TokenmonOnboardingBullet(text: TokenmonL10n.string("onboarding.welcome.bullet.explore"))
                        TokenmonOnboardingBullet(text: TokenmonL10n.string("onboarding.welcome.bullet.resolve"))
                        TokenmonOnboardingBullet(text: TokenmonL10n.string("onboarding.welcome.bullet.dex"))
                    }
                }
            }

            TokenmonCompactSection(
                title: TokenmonL10n.string("onboarding.welcome.next_steps.title"),
                systemImage: "list.bullet.clipboard"
            ) {
                Text(TokenmonL10n.string("onboarding.welcome.next_steps.body"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TokenmonOnboardingPermissionsStep: View {
    let appSettings: AppSettings
    let launchAtLoginState: TokenmonLaunchAtLoginState
    let notificationAuthorizationState: TokenmonNotificationAuthorizationState
    let onPerformSetupAction: (TokenmonSetupRecommendationAction) -> Void

    var body: some View {
        TokenmonSettingsSectionCard(
            title: TokenmonL10n.string("onboarding.permissions.section_title"),
            systemImage: "switch.2"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(TokenmonL10n.string("onboarding.permissions.body"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TokenmonSetupRecommendationList(
                    items: TokenmonSetupRecommendationsBuilder.items(
                        appSettings: appSettings,
                        launchAtLoginState: launchAtLoginState,
                        notificationAuthorizationState: notificationAuthorizationState
                    ),
                    onPerformAction: onPerformSetupAction
                )

                Text(TokenmonL10n.string("settings.general.quick_setup.note"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TokenmonOnboardingProvidersStep: View {
    let onboardingStatuses: [TokenmonProviderOnboardingStatus]
    let providerHealthSummaries: [ProviderHealthSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TokenmonProviderOverviewRow(
                summary: TokenmonSettingsPresentationBuilder.providerOverviewSummary(
                    onboardingStatuses: onboardingStatuses
                )
            )

            ForEach(onboardingStatuses, id: \.provider) { status in
                TokenmonOnboardingProviderSummaryCard(
                    status: status,
                    healthSummary: providerHealthSummaries.first(where: { $0.provider == status.provider })
                )
            }

            Text(TokenmonL10n.string("onboarding.providers.note"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct TokenmonOnboardingProviderSummaryCard: View {
    let status: TokenmonProviderOnboardingStatus
    let healthSummary: ProviderHealthSummary?

    var body: some View {
        TokenmonSettingsSectionCard(
            title: status.provider.displayName,
            systemImage: providerSystemImage
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.title)
                            .font(.headline)
                        Text(status.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    TokenmonOnboardingProviderStatusBadge(
                        state: TokenmonSettingsPresentationBuilder.providerCardState(for: status)
                    )
                }

                Text(
                    TokenmonSettingsPresentationBuilder.providerMetadataLine(
                        status: status,
                        healthSummary: healthSummary
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var providerSystemImage: String {
        switch status.provider {
        case .claude:
            return "bubble.left.and.bubble.right"
        case .codex:
            return "terminal"
        case .gemini:
            return "antenna.radiowaves.left.and.right"
        }
    }
}

private struct TokenmonOnboardingProviderStatusBadge: View {
    let state: TokenmonProviderCardState

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(state == .notFound ? 0.10 : 0.16))
            )
    }

    var title: String {
        switch state {
        case .connected:
            return TokenmonL10n.string("provider.card_state.connected")
        case .repair:
            return TokenmonL10n.string("provider.card_state.repair")
        case .needsSetup:
            return TokenmonL10n.string("provider.card_state.needs_setup")
        case .notFound:
            return TokenmonL10n.string("provider.card_state.not_found")
        }
    }

    var systemImage: String {
        switch state {
        case .connected:
            return "checkmark.circle.fill"
        case .repair:
            return "wrench.and.screwdriver.fill"
        case .needsSetup:
            return "exclamationmark.circle.fill"
        case .notFound:
            return "magnifyingglass"
        }
    }

    var tint: Color {
        switch state {
        case .connected:
            return .green
        case .repair:
            return .orange
        case .needsSetup:
            return .accentColor
        case .notFound:
            return .secondary
        }
    }
}

private struct TokenmonOnboardingBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .padding(.top, 6)
                .foregroundStyle(.secondary)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

enum TokenmonInstalledAppBundleSupport {
    static func isInstalledAppBundle(
        bundle: Bundle = .main,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> Bool {
        let bundleURL = bundle.bundleURL.standardizedFileURL
        let bundlePath = bundleURL.path
        let globalApplications = URL(fileURLWithPath: "/Applications", isDirectory: true).path + "/"
        let userApplications = homeDirectory
            .appendingPathComponent("Applications", isDirectory: true)
            .standardizedFileURL
            .path + "/"

        return bundleURL.pathExtension.lowercased() == "app"
            && bundle.bundleIdentifier != nil
            && (bundlePath.hasPrefix(globalApplications) || bundlePath.hasPrefix(userApplications))
    }
}
