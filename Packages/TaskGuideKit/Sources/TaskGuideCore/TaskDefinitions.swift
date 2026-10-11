import Foundation

/// High-level learning phases. Only BUILD is implemented in V0.
public enum LearningPhase: String, Sendable, CaseIterable, Identifiable, Hashable {
    case build
    case launch
    case space

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .build: return "Build"
        case .launch: return "Launch"
        case .space: return "Space"
        }
    }

    /// Launch and Space are not implemented task workflows in V0.
    public var isImplemented: Bool {
        self == .build
    }

    public var comingLaterLabel: String? {
        isImplemented ? nil : "Coming later"
    }
}

public enum TaskCompletionKind: String, Sendable, Hashable {
    /// Requires an explicit user acknowledgment action.
    case manualAcknowledgment
    /// Evaluated from a craft-state snapshot; no manual completion.
    case automaticCraftValidation
    /// Evaluated from a preflight-state snapshot; no manual completion.
    case automaticPreflightValidation
}

public struct BuildTaskDefinition: Sendable, Identifiable, Hashable {
    public let id: String
    public let index: Int
    public let title: String
    public let instruction: String
    public let targetID: GuidanceTargetID
    public let completionKind: TaskCompletionKind
    public let acknowledgmentLabel: String?

    public init(
        id: String,
        index: Int,
        title: String,
        instruction: String,
        targetID: GuidanceTargetID,
        completionKind: TaskCompletionKind,
        acknowledgmentLabel: String? = nil
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.instruction = instruction
        self.targetID = targetID
        self.completionKind = completionKind
        self.acknowledgmentLabel = acknowledgmentLabel
    }
}

/// The single V0 guided mission and its four BUILD steps.
public enum BuildMissionV0 {
    public static let missionTitle = "Build Your First Rocket"
    public static let boardHeader = "YOUR FIRST ROCKET"
    public static let buildCompleteMessage = "Build phase complete. Ready for the Launch phase."
    public static let startActionLabel = "Start Build"

    public static let tasks: [BuildTaskDefinition] = [
        BuildTaskDefinition(
            id: "understand-mission",
            index: 1,
            title: "Understand Your Mission",
            instruction: "Before building, understand your objective and the constraints your rocket must satisfy.",
            targetID: .missionBrief,
            completionKind: .manualAcknowledgment,
            acknowledgmentLabel: "I understand"
        ),
        BuildTaskDefinition(
            id: "find-parts",
            index: 2,
            title: "Find Your Rocket Parts",
            instruction: "Locate the Parts panel. Learn where the command core, fuel tank, and engine are selected.",
            targetID: .partsPalette,
            completionKind: .manualAcknowledgment,
            acknowledgmentLabel: "I've found the parts"
        ),
        BuildTaskDefinition(
            id: "check-components",
            index: 3,
            title: "Check Essential Components",
            instruction: "Make sure your rocket contains a command core, a fuel tank, and a liquid rocket engine.",
            targetID: .craftAssembly,
            completionKind: .automaticCraftValidation
        ),
        BuildTaskDefinition(
            id: "verify-readiness",
            index: 4,
            title: "Verify Launch Readiness",
            instruction: "Check the rocket's mass, thrust-to-weight ratio, and launch constraints before proceeding.",
            targetID: .statBoard,
            completionKind: .automaticPreflightValidation
        ),
    ]

    public static var taskCount: Int { tasks.count }

    public static func task(id: String) -> BuildTaskDefinition? {
        tasks.first { $0.id == id }
    }

    public static func task(at index: Int) -> BuildTaskDefinition? {
        tasks.first { $0.index == index }
    }
}
