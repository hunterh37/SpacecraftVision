import Foundation

/// How a task reached a completed presentation state.
public enum TaskCompletionRecord: String, Sendable, Equatable, Hashable {
    /// User pressed the acknowledgment control.
    case acknowledged
    /// Automatic validation passed after the task was previously unsatisfied.
    case validated
    /// Requirements were already met when the task became current.
    case alreadySatisfied
}

/// Visual / logical status for a single BUILD task row.
public enum TaskItemStatus: Sendable, Equatable, Hashable {
    case notStarted
    case current
    case completed(TaskCompletionRecord)
    case blocked(reason: String)

    public var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    public var accessibilityLabel: String {
        switch self {
        case .notStarted: return "Not Started"
        case .current: return "Current"
        case .completed(let record):
            switch record {
            case .acknowledged, .validated: return "Completed"
            case .alreadySatisfied: return "Already satisfied"
            }
        case .blocked: return "Blocked"
        }
    }
}

/// Session lifecycle for the task guide panel.
public enum GuideSessionPhase: String, Sendable, Equatable, Hashable {
    /// Overview with Start Build.
    case overview
    /// One of the four BUILD tasks is active.
    case inProgress
    /// All four BUILD tasks finished; show completion copy only.
    case buildComplete
    /// User exited the guide UI.
    case exited
}

/// Immutable view of guide progress for UI and tests.
public struct TaskGuideState: Sendable, Equatable {
    public var sessionPhase: GuideSessionPhase
    /// 1-based index of the current BUILD task while in progress; nil otherwise.
    public var currentTaskIndex: Int?
    public var completionRecords: [String: TaskCompletionRecord]
    public var activeTargetID: GuidanceTargetID?
    public var snapshot: CraftStateSnapshot
    /// Increments only when the host updates the craft snapshot input.
    public var snapshotMutationToken: Int

    public var completedTaskCount: Int {
        min(completionRecords.count, BuildMissionV0.taskCount)
    }

    public var totalTaskCount: Int { BuildMissionV0.taskCount }

    public var progressLabel: String {
        "\(completedTaskCount)/\(totalTaskCount)"
    }

    public var isBuildPhaseComplete: Bool {
        completedTaskCount == totalTaskCount
    }

    public func status(for task: BuildTaskDefinition) -> TaskItemStatus {
        if let record = completionRecords[task.id] {
            return .completed(record)
        }
        switch sessionPhase {
        case .overview, .exited, .buildComplete:
            return .notStarted
        case .inProgress:
            guard let current = currentTaskIndex else { return .notStarted }
            if task.index == current {
                return .current
            }
            if task.index > current {
                return .blocked(reason: "Complete the previous task first.")
            }
            return .notStarted
        }
    }

    public var currentTask: BuildTaskDefinition? {
        guard let currentTaskIndex else { return nil }
        return BuildMissionV0.task(at: currentTaskIndex)
    }

    public var componentValidation: ComponentValidationResult {
        TaskEvaluator.validateComponents(snapshot)
    }

    public var preflightValidation: PreflightValidationResult {
        TaskEvaluator.validatePreflight(snapshot)
    }
}

/// Deterministic in-memory task-state engine for BUILD V0.
public final class TaskGuideEngine: @unchecked Sendable {
    public private(set) var state: TaskGuideState

    /// Task IDs that were observed unsatisfied while current (drives validated vs alreadySatisfied).
    private var sawUnsatisfiedWhileCurrent: Set<String> = []

    public init(snapshot: CraftStateSnapshot = .init()) {
        self.state = TaskGuideState(
            sessionPhase: .overview,
            currentTaskIndex: nil,
            completionRecords: [:],
            activeTargetID: nil,
            snapshot: snapshot,
            snapshotMutationToken: 0
        )
    }

    // MARK: - Snapshot input

    /// Replaces the evaluation snapshot. Never mutates rocket data owned by the host app.
    public func updateSnapshot(_ snapshot: CraftStateSnapshot) {
        state.snapshot = snapshot
        state.snapshotMutationToken &+= 1
        recordUnsatisfiedIfNeeded()
        evaluateAutomaticTasksIfNeeded()
    }

    // MARK: - Session controls

    public func startBuild() {
        guard state.sessionPhase == .overview || state.sessionPhase == .exited else { return }
        state.sessionPhase = .inProgress
        activateTask(index: 1)
    }

    public func acknowledgeCurrent() {
        guard state.sessionPhase == .inProgress,
              let task = state.currentTask,
              task.completionKind == .manualAcknowledgment,
              state.completionRecords[task.id] == nil
        else { return }

        complete(task: task, record: .acknowledged)
    }

    /// Returns from the first in-progress task to the overview. Task review navigation is handled in UI.
    public func returnToOverview() {
        guard state.sessionPhase == .inProgress, state.currentTaskIndex == 1 else { return }
        state.sessionPhase = .overview
        state.currentTaskIndex = nil
        state.activeTargetID = nil
    }

    public func exitGuide() {
        state.sessionPhase = .exited
        state.currentTaskIndex = nil
        state.activeTargetID = nil
    }

    /// Resets only guide state. The craft snapshot input is left unchanged.
    public func resetGuide() {
        let preservedSnapshot = state.snapshot
        let preservedToken = state.snapshotMutationToken
        sawUnsatisfiedWhileCurrent.removeAll()
        state = TaskGuideState(
            sessionPhase: .overview,
            currentTaskIndex: nil,
            completionRecords: [:],
            activeTargetID: nil,
            snapshot: preservedSnapshot,
            snapshotMutationToken: preservedToken
        )
    }

    // MARK: - Internals

    private func activateTask(index: Int) {
        state.currentTaskIndex = index
        applyActiveTarget()
        recordUnsatisfiedIfNeeded()
        evaluateAutomaticTasksIfNeeded()
    }

    private func applyActiveTarget() {
        if state.sessionPhase == .inProgress, let task = state.currentTask {
            state.activeTargetID = task.targetID
        } else {
            state.activeTargetID = nil
        }
    }

    private func isSatisfied(_ task: BuildTaskDefinition) -> Bool {
        switch task.completionKind {
        case .manualAcknowledgment:
            return false
        case .automaticCraftValidation:
            return TaskEvaluator.validateComponents(state.snapshot).isSatisfied
        case .automaticPreflightValidation:
            return TaskEvaluator.validatePreflight(state.snapshot).isSatisfied
        }
    }

    private func recordUnsatisfiedIfNeeded() {
        guard state.sessionPhase == .inProgress,
              let task = state.currentTask,
              state.completionRecords[task.id] == nil,
              task.completionKind != .manualAcknowledgment
        else { return }

        if !isSatisfied(task) {
            sawUnsatisfiedWhileCurrent.insert(task.id)
        }
    }

    private func complete(task: BuildTaskDefinition, record: TaskCompletionRecord) {
        guard state.completionRecords[task.id] == nil else { return }
        guard state.completionRecords.count < BuildMissionV0.taskCount else { return }

        state.completionRecords[task.id] = record

        if state.completedTaskCount >= BuildMissionV0.taskCount {
            state.sessionPhase = .buildComplete
            state.currentTaskIndex = nil
            state.activeTargetID = nil
            return
        }

        activateTask(index: task.index + 1)
    }

    private func evaluateAutomaticTasksIfNeeded() {
        guard state.sessionPhase == .inProgress,
              let task = state.currentTask,
              state.completionRecords[task.id] == nil,
              task.completionKind != .manualAcknowledgment
        else { return }

        guard isSatisfied(task) else { return }

        let record: TaskCompletionRecord = sawUnsatisfiedWhileCurrent.contains(task.id)
            ? .validated
            : .alreadySatisfied
        complete(task: task, record: record)
    }
}
