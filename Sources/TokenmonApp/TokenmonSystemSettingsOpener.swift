import AppKit
import Foundation

enum TokenmonNotificationSettingsOpenResult: Equatable, Sendable {
    case openedAppSpecific
    case openedGenericNotifications
    case openedSystemSettingsRoot
    case failed
}

struct TokenmonNotificationSettingsDestination: Equatable, Sendable {
    let url: URL
    let result: TokenmonNotificationSettingsOpenResult
}

enum TokenmonSystemSettingsOpener {
    static func openNotificationSettings(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        openURL: (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) -> TokenmonNotificationSettingsOpenResult {
        for destination in notificationSettingsDestinations(bundleIdentifier: bundleIdentifier) {
            if openURL(destination.url) {
                return destination.result
            }
        }

        return .failed
    }

    static func notificationSettingsDestinations(bundleIdentifier: String?) -> [TokenmonNotificationSettingsDestination] {
        var destinations: [TokenmonNotificationSettingsDestination] = []

        if let bundleIdentifier, bundleIdentifier.isEmpty == false {
            destinations.append(
                TokenmonNotificationSettingsDestination(
                    url: URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleIdentifier)")!,
                    result: .openedAppSpecific
                )
            )
            destinations.append(
                TokenmonNotificationSettingsDestination(
                    url: URL(string: "x-apple.systempreferences:com.apple.preference.notifications?id=\(bundleIdentifier)")!,
                    result: .openedAppSpecific
                )
            )
        }

        destinations.append(
            TokenmonNotificationSettingsDestination(
                url: URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!,
                result: .openedGenericNotifications
            )
        )
        destinations.append(
            TokenmonNotificationSettingsDestination(
                url: URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!,
                result: .openedGenericNotifications
            )
        )
        destinations.append(
            TokenmonNotificationSettingsDestination(
                url: URL(string: "x-apple.systempreferences:")!,
                result: .openedSystemSettingsRoot
            )
        )
        return destinations
    }

    static func notificationSettingsURLs(bundleIdentifier: String?) -> [URL] {
        notificationSettingsDestinations(bundleIdentifier: bundleIdentifier).map(\.url)
    }
}
