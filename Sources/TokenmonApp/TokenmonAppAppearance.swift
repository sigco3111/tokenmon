import AppKit
import SwiftUI
import TokenmonPersistence

extension AppAppearancePreference {
    var appKitAppearanceName: NSAppearance.Name? {
        switch self {
        case .system:
            return nil
        case .light:
            return .aqua
        case .dark:
            return .darkAqua
        }
    }

    var colorSchemeOverride: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

@MainActor
enum TokenmonAppAppearanceController {
    static func apply(_ preference: AppAppearancePreference, application: NSApplication = .shared) {
        let appearance = resolvedAppearance(for: preference)
        application.appearance = appearance
        syncHostWindows(application.windows, appearance: appearance)
    }

    static func resolvedAppearance(for preference: AppAppearancePreference) -> NSAppearance? {
        preference.appKitAppearanceName.flatMap(NSAppearance.init(named:))
    }

    static func syncHostWindows(_ windows: [NSWindow], appearance: NSAppearance?) {
        for window in windows {
            syncHostWindow(window, appearance: appearance)
        }
    }

    static func syncHostWindow(_ window: NSWindow?, appearance: NSAppearance? = NSApp.appearance) {
        guard let window else {
            return
        }

        window.appearance = appearance
        window.contentViewController?.view.appearance = appearance
        window.contentView?.needsLayout = true
        window.contentView?.needsDisplay = true
    }
}

extension View {
    func tokenmonPreferredColorScheme(_ preference: AppAppearancePreference) -> some View {
        preferredColorScheme(preference.colorSchemeOverride)
    }
}
