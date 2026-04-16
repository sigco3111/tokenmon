import AppKit
import Foundation

enum TokenmonSystemSettingsOpener {
    static func openNotificationSettings(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        openURL: (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) -> Bool {
        for url in notificationSettingsURLs(bundleIdentifier: bundleIdentifier) {
            if openURL(url) {
                return true
            }
        }

        return false
    }

    static func notificationSettingsURLs(bundleIdentifier: String?) -> [URL] {
        var urls: [URL] = []

        if let bundleIdentifier, bundleIdentifier.isEmpty == false {
            urls.append(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleIdentifier)")!)
            urls.append(URL(string: "x-apple.systempreferences:com.apple.preference.notifications?id=\(bundleIdentifier)")!)
        }

        urls.append(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
        urls.append(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
        urls.append(URL(string: "x-apple.systempreferences:")!)
        return urls
    }
}
