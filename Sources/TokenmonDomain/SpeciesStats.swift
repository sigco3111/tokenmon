import Foundation

/// The six developer-domain stat axes. Each species has a value 1–10 per axis.
public enum SpeciesStatAxis: String, CaseIterable, Sendable {
    case planning
    case design
    case frontend
    case backend
    case pm
    case infra

    public var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .design: return "Design"
        case .frontend: return "Frontend"
        case .backend: return "Backend"
        case .pm: return "PM"
        case .infra: return "Infra"
        }
    }
}

/// A species' complete stat block: 6 axis values + trait tags.
public struct SpeciesStatBlock: Equatable, Codable, Sendable {
    public let planning: Int
    public let design: Int
    public let frontend: Int
    public let backend: Int
    public let pm: Int
    public let infra: Int
    public let traits: [String]

    public var total: Int {
        planning + design + frontend + backend + pm + infra
    }

    public func value(for axis: SpeciesStatAxis) -> Int {
        switch axis {
        case .planning: return planning
        case .design: return design
        case .frontend: return frontend
        case .backend: return backend
        case .pm: return pm
        case .infra: return infra
        }
    }

    public init(
        planning: Int, design: Int, frontend: Int,
        backend: Int, pm: Int, infra: Int,
        traits: [String] = []
    ) {
        self.planning = planning
        self.design = design
        self.frontend = frontend
        self.backend = backend
        self.pm = pm
        self.infra = infra
        self.traits = traits
    }
}

/// Canonical trait tag pools organized by association.
public enum SpeciesTraitPool {
    /// Domain-linked tags. Each sub-array maps to one SpeciesStatAxis.
    /// A domain tag should only be assigned when its linked stat is in the species' top 2.
    public static let domainTags: [SpeciesStatAxis: [String]] = [
        .planning: ["Visionary", "Strategist", "Scope Master", "User Advocate", "Roadmap Guru", "Spec Writer", "Feature Hunter"],
        .design: ["Pixel Perfect", "Color Whisperer", "Layout Genius", "Motion Crafter", "Minimalist", "Brand Guardian", "Icon Artist"],
        .frontend: ["Quick Prototyper", "CSS Wizard", "Animation Pro", "Component Builder", "Responsive Guru", "Accessibility First", "State Juggler"],
        .backend: ["Debug Master", "API Architect", "Query Optimizer", "Data Modeler", "Error Handler", "Cache Wizard", "Concurrency Pro"],
        .pm: ["Sprint Leader", "Deadline Keeper", "Stakeholder Whisperer", "Risk Spotter", "Team Builder", "Blocker Breaker", "Metric Tracker"],
        .infra: ["Pipeline Builder", "Cloud Native", "Security Guard", "Scale Master", "Container Wizard", "Monitoring Hawk", "SRE Soul"],
    ]

    /// Style tags. Domain-agnostic work personality traits.
    public static let styleTags: [String] = [
        "Night Owl", "Early Bird", "Deep Focus", "Multitasker",
        "Fast Typer", "Refactor King", "Pair Programmer", "Solo Worker",
        "Documentation Lover", "Coffee Addict", "Rubber Ducker", "Clean Coder",
        "Speed Runner", "Perfectionist", "Experimenter", "Mentor",
        "Git Historian", "Terminal Lover", "Shortcut Master", "Emoji Coder",
    ]
}
