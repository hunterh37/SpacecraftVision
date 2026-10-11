import Foundation

/// Stable semantic identifiers for guidance targets.
/// Future RealityKit integration should reuse these identifiers rather than screen coordinates.
public enum GuidanceTargetID: String, Sendable, Codable, Hashable, CaseIterable {
    case missionBrief
    case partsPalette
    case craftAssembly
    case statBoard

    public var displayLabel: String {
        switch self {
        case .missionBrief: return "Mission Brief"
        case .partsPalette: return "Parts Palette"
        case .craftAssembly: return "Craft Assembly"
        case .statBoard: return "Stat Board"
        }
    }
}
