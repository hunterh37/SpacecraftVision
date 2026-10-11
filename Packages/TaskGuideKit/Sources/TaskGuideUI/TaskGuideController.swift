import Foundation
import Observation
import TaskGuideCore

/// Observable wrapper around `TaskGuideEngine` for SwiftUI presentation.
@Observable
@MainActor
public final class TaskGuideController {
    private let engine: TaskGuideEngine

    public private(set) var state: TaskGuideState
    /// Optional review focus for completed tasks; does not affect engine advancement.
    public private(set) var reviewTaskIndex: Int?

    public init(snapshot: CraftStateSnapshot = .init()) {
        let engine = TaskGuideEngine(snapshot: snapshot)
        self.engine = engine
        self.state = engine.state
    }

    /// True while reviewing a completed task (including after build-complete).
    public var isReviewing: Bool { reviewTaskIndex != nil }

    public var displayedTask: BuildTaskDefinition? {
        if let reviewTaskIndex {
            return BuildMissionV0.task(at: reviewTaskIndex)
        }
        return state.currentTask
    }

    public var displayedTargetID: GuidanceTargetID? {
        switch state.sessionPhase {
        case .overview, .exited, .buildComplete:
            // Highlight only while actively reviewing a completed task after build-complete.
            if state.sessionPhase == .buildComplete, let reviewTaskIndex {
                return BuildMissionV0.task(at: reviewTaskIndex)?.targetID
            }
            return nil
        case .inProgress:
            return displayedTask?.targetID ?? state.activeTargetID
        }
    }

    /// Whether any automatic task completed as already-satisfied (prebuilt craft path).
    public var hadAlreadySatisfiedAutomaticTask: Bool {
        state.completionRecords.values.contains(.alreadySatisfied)
    }

    public func updateSnapshot(_ snapshot: CraftStateSnapshot) {
        engine.updateSnapshot(snapshot)
        refresh()
    }

    public func startBuild() {
        clearReviewFocus()
        engine.startBuild()
        refresh()
    }

    public func acknowledgeCurrent() {
        clearReviewFocus()
        engine.acknowledgeCurrent()
        refresh()
    }

    public func goBack() {
        if let review = reviewTaskIndex {
            if review > 1 {
                reviewTaskIndex = review - 1
            } else {
                // Leave review of task 1. Only return to overview when advancement is still on task 1
                // with no completions beyond it (i.e. user backed out before acknowledging).
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
        case .buildComplete:
            // Enter review of the last completed task without clearing completion.
            reviewTaskIndex = BuildMissionV0.taskCount
        case .inProgress:
            guard let current = state.currentTaskIndex else { return }
            if current <= 1 {
                engine.returnToOverview()
                refresh()
            } else {
                // Review the previous completed task; do not rewind engine progress.
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
        guard let task = BuildMissionV0.task(at: index) else { return }
        let status = state.status(for: task)
        switch status {
        case .completed:
            reviewTaskIndex = index
        case .current:
            clearReviewFocus()
        case .notStarted, .blocked:
            break
        }
    }

    /// Clears review focus and returns to the live current task or completion summary.
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
