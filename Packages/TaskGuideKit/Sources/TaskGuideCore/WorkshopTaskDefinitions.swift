import Foundation

public enum LearningPhase: String, Sendable, CaseIterable, Identifiable, Hashable {
    case workshop
    case launch
    case space

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .workshop: return "Workshop"
        case .launch: return "Launch"
        case .space: return "Space"
        }
    }

    public var isImplemented: Bool { self == .workshop }

    public var comingLaterLabel: String? { isImplemented ? nil : "Coming later" }
}

public enum WorkshopTaskID: String, Sendable, CaseIterable, Identifiable, Hashable {
    case w01UnderstandMission = "W01"
    case w02IdentifyComponents = "W02"
    case w03ExploreScale = "W03"
    case w04CheckDesign = "W04"

    public var id: String { rawValue }

    public var index: Int {
        switch self {
        case .w01UnderstandMission: return 1
        case .w02IdentifyComponents: return 2
        case .w03ExploreScale: return 3
        case .w04CheckDesign: return 4
        }
    }

    public var title: String {
        switch self {
        case .w01UnderstandMission: return "Understand Your Mission"
        case .w02IdentifyComponents: return "Identify Rocket Components"
        case .w03ExploreScale: return "Explore the Rocket"
        case .w04CheckDesign: return "Check Your Design"
        }
    }

    public var instruction: String {
        switch self {
        case .w01UnderstandMission:
            return "Review the current mission objective and the constraints your rocket must satisfy."
        case .w02IdentifyComponents:
            return "Select each essential component in the Parts stack to learn its role."
        case .w03ExploreScale:
            return "Use Tabletop Scale to compare life-size and miniature views of the rocket."
        case .w04CheckDesign:
            return "Inspect mass, cost, parts, TWR, and blockers, then check the design."
        }
    }

    public var targetID: GuidanceTargetID {
        switch self {
        case .w01UnderstandMission: return .missionBrief
        case .w02IdentifyComponents: return .partsStack
        case .w03ExploreScale: return .tabletopToggle
        case .w04CheckDesign: return .statBoard
        }
    }
}

public enum WorkshopMissionV2 {
    public static let boardHeader = "WORKSHOP GUIDE"
    public static let missionTitle = "Inspect Your Rocket"
    public static let startActionLabel = "Start Workshop Guide"
    public static let completeTitle = "WORKSHOP CHECKS COMPLETE"
    public static let completeSubtitle = "You've inspected your rocket and verified its basic design constraints."
    public static let continueToRangeLabel = "Continue to Launch Range"
    public static let checkDesignLabel = "Check Design"
    public static let checkAgainLabel = "Check Again"
    public static let openPartsLabel = "Open Parts"
    public static let understandLabel = "I Understand"
    public static let twrExplanation = "TWR compares rocket thrust with its weight. A value above 1.0 is needed for liftoff in this guide."

    public static let tasks: [WorkshopTaskID] = WorkshopTaskID.allCases
    public static var taskCount: Int { tasks.count }

    public static let componentOrder: [EssentialPartID] = [
        .probeCore, .fuelTankS, .engineLiquidSmall
    ]
}
