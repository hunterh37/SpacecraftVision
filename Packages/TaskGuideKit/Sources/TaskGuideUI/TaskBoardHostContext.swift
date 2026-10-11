import Foundation

public struct TaskBoardHostContext: Sendable {
    public var missionHeadline: String?
    public var missionDetails: String?
    public var readinessNote: String?
    public var showsOpenPartsAction: Bool
    public var showsGoToLaunchRangeAction: Bool

    public init(
        missionHeadline: String? = nil,
        missionDetails: String? = nil,
        readinessNote: String? = nil,
        showsOpenPartsAction: Bool = false,
        showsGoToLaunchRangeAction: Bool = false
    ) {
        self.missionHeadline = missionHeadline
        self.missionDetails = missionDetails
        self.readinessNote = readinessNote
        self.showsOpenPartsAction = showsOpenPartsAction
        self.showsGoToLaunchRangeAction = showsGoToLaunchRangeAction
    }

    public static let demo = TaskBoardHostContext()
}
