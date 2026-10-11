import Foundation

/// Optional host-provided chrome for integrating the task board into the Vision Pro app.
/// Standalone demos may omit this (defaults leave host actions unavailable).
public struct TaskBoardHostContext: Sendable {
    public var missionHeadline: String?
    public var missionDetails: String?
    /// Neutral completion note, e.g. "Rocket components verified".
    public var completionNote: String?
    public var showsOpenPartsAction: Bool
    public var showsGoToLaunchRangeAction: Bool

    public init(
        missionHeadline: String? = nil,
        missionDetails: String? = nil,
        completionNote: String? = nil,
        showsOpenPartsAction: Bool = false,
        showsGoToLaunchRangeAction: Bool = false
    ) {
        self.missionHeadline = missionHeadline
        self.missionDetails = missionDetails
        self.completionNote = completionNote
        self.showsOpenPartsAction = showsOpenPartsAction
        self.showsGoToLaunchRangeAction = showsGoToLaunchRangeAction
    }

    public static let demo = TaskBoardHostContext()
}
