import Foundation
import Observation
import TaskGuideCore

@Observable
@MainActor
public final class TaskGuideController {
    private let engine: WorkshopGuideEngine

    public private(set) var state: WorkshopGuideState
    public private(set) var reviewTaskIndex: Int?

    public init(snapshot: CraftStateSnapshot = .init()) {
        let engine = WorkshopGuideEngine(snapshot: snapshot)
        self.engine = engine
        self.state = engine.state
    }

    public var isReviewing: Bool { reviewTaskIndex != nil }

    public var displayedTaskID: WorkshopTaskID? {
        if let reviewTaskIndex {
            return WorkshopTaskID.allCases.first { $0.index == reviewTaskIndex }
        }
        return state.currentTaskID
    }

    public var displayedTargetID: GuidanceTargetID? {
        switch state.sessionPhase {
        case .overview, .exited:
            return nil
        case .workshopComplete:
            return reviewTaskIndex.flatMap { idx in WorkshopTaskID.allCases.first { $0.index == idx }?.targetID }
        case .inProgress:
            return displayedTaskID?.targetID
        }
    }

    public func updateSnapshot(_ snapshot: CraftStateSnapshot) {
        engine.updateSnapshot(snapshot)
        refresh()
    }

    public func startGuide() {
        clearReviewFocus()
        engine.startGuide()
        refresh()
    }

    public func acknowledgeMission() {
        clearReviewFocus()
        engine.acknowledgeMission()
        refresh()
    }

    public func noteComponentSelection(partID: String) {
        engine.noteComponentSelection(partID: partID)
        refresh()
    }

    public func noteTabletopScaleChanged(newValue: Bool, userInitiated: Bool) {
        engine.noteTabletopScaleChanged(newValue: newValue, userInitiated: userInitiated)
        refresh()
    }

    public func checkDesign() {
        clearReviewFocus()
        engine.checkDesign()
        refresh()
    }

    public func goBack() {
        if let review = reviewTaskIndex {
            if review > 1 {
                reviewTaskIndex = review - 1
            } else {
                clearReviewFocus()
                if state.sessionPhase == .inProgress,
                   state.currentTaskIndex == 1,
                   state.completionRecords.isEmpty
                {
                    engine.returnToOverview()
                    refresh()
                }
            }
            return
        }

        switch state.sessionPhase {
        case .overview, .exited:
            return
        case .workshopComplete:
            reviewTaskIndex = WorkshopMissionV2.taskCount
        case .inProgress:
            guard let current = state.currentTaskIndex else { return }
            if current <= 1 {
                engine.returnToOverview()
                refresh()
            } else {
                reviewTaskIndex = current - 1
            }
        }
    }

    public func exitGuide() {
        clearReviewFocus()
        engine.exitGuide()
        refresh()
    }

    public func resetGuide() {
        clearReviewFocus()
        engine.resetGuide()
        refresh()
    }

    public func focusTask(index: Int) {
        guard let task = WorkshopTaskID.allCases.first(where: { $0.index == index }) else { return }
        switch state.status(for: task) {
        case .completed:
            reviewTaskIndex = index
        case .current:
            clearReviewFocus()
        case .notStarted, .blocked:
            break
        }
    }

    public func returnToLive() {
        clearReviewFocus()
    }

    public func clearReviewFocus() {
        reviewTaskIndex = nil
    }

    private func refresh() {
        state = engine.state
        if state.sessionPhase == .overview || state.sessionPhase == .exited {
            reviewTaskIndex = nil
        }
    }
}
