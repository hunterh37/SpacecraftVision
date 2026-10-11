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

    public var displayedTask: BuildTaskDefinition? {
        if let reviewTaskIndex {
            return BuildMissionV0.task(at: reviewTaskIndex)
        }
        if state.sessionPhase == .buildComplete {
            return BuildMissionV0.tasks.last
        }
        return state.currentTask
    }

    public var displayedTargetID: GuidanceTargetID? {
        switch state.sessionPhase {
        case .overview, .exited:
            return nil
        case .buildComplete, .inProgress:
            return displayedTask?.targetID
        }
    }

    public func updateSnapshot(_ snapshot: CraftStateSnapshot) {
        engine.updateSnapshot(snapshot)
        refresh()
    }

    public func startBuild() {
        reviewTaskIndex = nil
        engine.startBuild()
        refresh()
    }

    public func acknowledgeCurrent() {
        reviewTaskIndex = nil
        engine.acknowledgeCurrent()
        refresh()
    }

    public func goBack() {
        if let review = reviewTaskIndex {
            if review > 1 {
                reviewTaskIndex = review - 1
            } else {
                // From reviewing task 1, leave review; if advancement is still on task 1, show overview.
                reviewTaskIndex = nil
                if state.currentTaskIndex == 1 {
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
            reviewTaskIndex = BuildMissionV0.taskCount
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
        reviewTaskIndex = nil
        engine.exitGuide()
        refresh()
    }

    public func resetGuide() {
        reviewTaskIndex = nil
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
            reviewTaskIndex = nil
        case .notStarted, .blocked:
            break
        }
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
