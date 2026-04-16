import AppKit
import Foundation

enum TokenmonBrandLink: String, CaseIterable, Identifiable {
    case website
    case github

    private static let githubLightMarkImage = loadImage(named: "github-invertocat-black")
    private static let githubDarkMarkImage = loadImage(named: "github-invertocat-white")
    private static let defaultGitHubRepository = "aroido/tokenmon"
    private static let bundledGitHubRepository = resolveGitHubRepository()

    var id: Self { self }

    var titleKey: StaticString {
        switch self {
        case .website:
            return "common.website"
        case .github:
            return "common.github"
        }
    }

    var compactTitleKey: StaticString {
        switch self {
        case .website:
            return "brand.aroido"
        case .github:
            return "common.github"
        }
    }

    var compactSymbolName: String {
        switch self {
        case .website:
            return "globe"
        case .github:
            return "chevron.left.forwardslash.chevron.right"
        }
    }

    var usesBrandMark: Bool {
        switch self {
        case .website:
            return false
        case .github:
            return true
        }
    }

    var destination: URL {
        switch self {
        case .website:
            return URL(string: "https://aroido.com/")!
        case .github:
            return URL(string: "https://github.com/\(Self.bundledGitHubRepository)")!
        }
    }

    var displayValue: String {
        switch self {
        case .website:
            return "aroido.com"
        case .github:
            return "github.com/\(Self.bundledGitHubRepository)"
        }
    }

    var homeChipWidth: CGFloat {
        92
    }

    var brandMarkImage: NSImage? {
        brandMarkImage(forDarkAppearance: false)
    }

    func brandMarkImage(forDarkAppearance: Bool) -> NSImage? {
        switch self {
        case .website:
            return nil
        case .github:
            return forDarkAppearance ? Self.githubDarkMarkImage : Self.githubLightMarkImage
        }
    }

    private static func loadImage(named resourceName: String) -> NSImage? {
        guard let url = TokenmonAppResourceBundle.current.url(forResource: resourceName, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private static func resolveGitHubRepository(bundle: Bundle = .main) -> String {
        guard let rawValue = bundle.object(forInfoDictionaryKey: "TokenmonGitHubRepository") as? String else {
            return defaultGitHubRepository
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("/") else {
            return defaultGitHubRepository
        }

        return trimmed
    }
}
