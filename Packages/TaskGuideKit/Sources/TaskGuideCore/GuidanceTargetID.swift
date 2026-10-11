import Foundation

/// Stable semantic identifiers for Workshop guidance targets.
public enum GuidanceTargetID: String, Sendable, Codable, Hashable, CaseIterable {
    case missionBrief
    case partsStack
    case tabletopToggle
    case craftAssembly
    case statBoard

    public var displayLabel: String {
        switch self {
        case .missionBrief: return "Mission Brief"
        case .partsStack: return "Parts Stack"
        case .tabletopToggle: return "Tabletop Scale"
        case .craftAssembly: return "Craft Assembly"
        case .statBoard: return "Stat Board"
        }
    }
}
