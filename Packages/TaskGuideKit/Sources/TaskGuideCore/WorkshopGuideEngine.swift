import Foundation

public enum TaskCompletionRecord: String, Sendable, Equatable, Hashable {
    case acknowledged
    case interacted
    case validated
}

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
        case .completed: return "Completed"
        case .blocked: return "Blocked"
        }
    }
}

public enum GuideSessionPhase: String, Sendable, Equatable, Hashable {
    case overview
    case inProgress
    case workshopComplete
    case exited
}

public struct WorkshopGuideState: Sendable, Equatable {
    public var sessionPhase: GuideSessionPhase
    public var currentTaskIndex: Int?
    public var completionRecords: [WorkshopTaskID: TaskCompletionRecord]
    public var componentSubstepIndex: Int?
    public var completedComponentSubsteps: Int
    public var lastComponentExplanation: String?
    public var snapshot: CraftStateSnapshot
    public var snapshotMutationToken: Int
    /// True only after an explicit successful Check Design while the craft remains valid.
    public var currentDesignReady: Bool
    public var lastDesignValidation: DesignValidationResult?
    public var needsMissionReview: Bool
    public var boundMissionID: String?

    public var completedTaskCount: Int {
        min(completionRecords.count, WorkshopMissionV2.taskCount)
    }

    public var totalTaskCount: Int { WorkshopMissionV2.taskCount }

    public var progressLabel: String { "\(completedTaskCount)/\(totalTaskCount)" }

    public var allTasksHistoricallyComplete: Bool {
        WorkshopTaskID.allCases.allSatisfy { completionRecords[$0] != nil }
    }

    public var canContinueToLaunchRange: Bool {
        allTasksHistoricallyComplete && currentDesignReady && !needsMissionReview
    }

    public var currentTaskID: WorkshopTaskID? {
        guard let currentTaskIndex else { return nil }
        return WorkshopTaskID.allCases.first { $0.index == currentTaskIndex }
    }

    public var expectedComponent: EssentialPartID? {
        guard let componentSubstepIndex,
              WorkshopMissionV2.componentOrder.indices.contains(componentSubstepIndex)
        else { return nil }
        return WorkshopMissionV2.componentOrder[componentSubstepIndex]
    }

    public func status(for task: WorkshopTaskID) -> TaskItemStatus {
        if let record = completionRecords[task] {
            return .completed(record)
        }
        switch sessionPhase {
        case .overview, .exited, .workshopComplete:
            return .notStarted
        case .inProgress:
            guard let current = currentTaskIndex else { return .notStarted }
            if task.index == current { return .current }
            if task.index > current { return .blocked(reason: "Complete the previous task first.") }
            return .notStarted
        }
    }
}

/// Deterministic Workshop V2 guide engine. Interaction-driven; never mutates craft data.
public final class WorkshopGuideEngine: @unchecked Sendable {
    public private(set) var state: WorkshopGuideState
    private var tabletopAtW03Activation: Bool = false
    /// After a historically completed W04 becomes invalid, require an explicit Check Again.
    private var readinessNeedsRecheck = false

    public init(snapshot: CraftStateSnapshot = .init()) {
        self.state = WorkshopGuideState(
            sessionPhase: .overview,
            currentTaskIndex: nil,
            completionRecords: [:],
            componentSubstepIndex: nil,
            completedComponentSubsteps: 0,
            lastComponentExplanation: nil,
            snapshot: snapshot,
            snapshotMutationToken: 0,
            currentDesignReady: false,
            lastDesignValidation: nil,
            needsMissionReview: false,
            boundMissionID: snapshot.missionID.isEmpty ? nil : snapshot.missionID
        )
    }

    // MARK: Snapshot

    public func updateSnapshot(_ snapshot: CraftStateSnapshot) {
        let previousMission = state.boundMissionID
        state.snapshot = snapshot
        state.snapshotMutationToken &+= 1

        if let previousMission, !snapshot.missionID.isEmpty, snapshot.missionID != previousMission {
            handleMissionChange(to: snapshot.missionID)
        } else if state.boundMissionID == nil, !snapshot.missionID.isEmpty {
            state.boundMissionID = snapshot.missionID
        }

        refreshCurrentReadiness()
    }

    // MARK: Session

    public func startGuide() {
        guard state.sessionPhase == .overview || state.sessionPhase == .exited else { return }

        if state.allTasksHistoricallyComplete && !state.needsMissionReview {
            state.sessionPhase = .workshopComplete
            state.currentTaskIndex = nil
            state.componentSubstepIndex = nil
            refreshCurrentReadiness()
            return
        }

        state.sessionPhase = .inProgress
        if state.needsMissionReview || state.completionRecords[.w01UnderstandMission] == nil {
            activateTask(index: 1)
            return
        }
        let next = WorkshopTaskID.allCases.first { state.completionRecords[$0] == nil }?.index ?? 1
        activateTask(index: next)
    }

    public func acknowledgeMission() {
        guard state.sessionPhase == .inProgress,
              state.currentTaskID == .w01UnderstandMission,
              state.completionRecords[.w01UnderstandMission] == nil
        else { return }
        state.needsMissionReview = false
        state.boundMissionID = state.snapshot.missionID
        complete(task: .w01UnderstandMission, record: .acknowledged)
    }

    /// Explicit Parts stack selection. Call from the UI action even when the row was already selected.
    public func noteComponentSelection(partID: String) {
        guard state.sessionPhase == .inProgress,
              state.currentTaskID == .w02IdentifyComponents,
              let expected = state.expectedComponent,
              state.completionRecords[.w02IdentifyComponents] == nil
        else { return }

        guard partID == expected.rawValue else { return }

        state.lastComponentExplanation = expected.roleExplanation
        state.completedComponentSubsteps += 1
        let next = (state.componentSubstepIndex ?? 0) + 1
        if next >= WorkshopMissionV2.componentOrder.count {
            complete(task: .w02IdentifyComponents, record: .interacted)
        } else {
            state.componentSubstepIndex = next
        }
    }

    /// User-initiated tabletop toggle only. Programmatic changes must pass `userInitiated: false`.
    public func noteTabletopScaleChanged(newValue: Bool, userInitiated: Bool) {
        guard userInitiated,
              state.sessionPhase == .inProgress,
              state.currentTaskID == .w03ExploreScale,
              state.completionRecords[.w03ExploreScale] == nil
        else { return }

        guard newValue != tabletopAtW03Activation else { return }
        complete(task: .w03ExploreScale, record: .interacted)
    }

    /// Explicit design validation. Never auto-completes from snapshot alone.
    public func checkDesign() {
        let result = TaskEvaluator.validateDesign(state.snapshot)
        state.lastDesignValidation = result

        if state.needsMissionReview {
            state.currentDesignReady = false
            return
        }

        if state.sessionPhase == .inProgress, state.currentTaskID == .w04CheckDesign {
            guard result.isSatisfied else {
                state.currentDesignReady = false
                readinessNeedsRecheck = true
                return
            }
            state.currentDesignReady = true
            readinessNeedsRecheck = false
            if state.completionRecords[.w04CheckDesign] == nil {
                complete(task: .w04CheckDesign, record: .validated)
            }
            return
        }

        // Renewed validation after historical W04 completion (or from completion summary).
        if state.completionRecords[.w04CheckDesign] != nil {
            guard result.isSatisfied else {
                state.currentDesignReady = false
                readinessNeedsRecheck = true
                return
            }
            state.currentDesignReady = true
            readinessNeedsRecheck = false
        }
    }

    public func returnToOverview() {
        guard state.sessionPhase == .inProgress, state.currentTaskIndex == 1 else { return }
        state.sessionPhase = .overview
        state.currentTaskIndex = nil
        state.componentSubstepIndex = nil
    }

    public func exitGuide() {
        state.sessionPhase = .exited
        state.currentTaskIndex = nil
        state.componentSubstepIndex = nil
    }

    public func resetGuide() {
        let snap = state.snapshot
        let token = state.snapshotMutationToken
        tabletopAtW03Activation = snap.workshopTabletop
        readinessNeedsRecheck = false
        state = WorkshopGuideState(
            sessionPhase: .overview,
            currentTaskIndex: nil,
            completionRecords: [:],
            componentSubstepIndex: nil,
            completedComponentSubsteps: 0,
            lastComponentExplanation: nil,
            snapshot: snap,
            snapshotMutationToken: token,
            currentDesignReady: false,
            lastDesignValidation: nil,
            needsMissionReview: false,
            boundMissionID: snap.missionID.isEmpty ? nil : snap.missionID
        )
    }

    // MARK: Internals

    private func activateTask(index: Int) {
        state.sessionPhase = .inProgress
        state.currentTaskIndex = index
        state.componentSubstepIndex = nil
        state.lastComponentExplanation = nil

        if index == WorkshopTaskID.w02IdentifyComponents.index {
            state.componentSubstepIndex = 0
            state.completedComponentSubsteps = 0
        }
        if index == WorkshopTaskID.w03ExploreScale.index {
            tabletopAtW03Activation = state.snapshot.workshopTabletop
        }
        if index == WorkshopTaskID.w04CheckDesign.index {
            state.currentDesignReady = false
            state.lastDesignValidation = nil
        }
    }

    private func complete(task: WorkshopTaskID, record: TaskCompletionRecord) {
        guard state.completionRecords[task] == nil else { return }
        state.completionRecords[task] = record
        state.componentSubstepIndex = nil

        if state.allTasksHistoricallyComplete {
            state.sessionPhase = .workshopComplete
            state.currentTaskIndex = nil
            refreshCurrentReadiness()
            return
        }

        // Skip already-completed tasks (e.g. after mission change, W02/W03 remain done).
        if let next = WorkshopTaskID.allCases.first(where: { state.completionRecords[$0] == nil }) {
            activateTask(index: next.index)
        }
    }

    private func handleMissionChange(to missionID: String) {
        state.boundMissionID = missionID
        state.needsMissionReview = true
        state.currentDesignReady = false
        state.lastDesignValidation = nil
        readinessNeedsRecheck = true
        state.completionRecords[.w01UnderstandMission] = nil
        state.completionRecords[.w04CheckDesign] = nil
        // Preserve W02 / W03 learning history.

        if state.sessionPhase == .overview {
            return
        }
        state.sessionPhase = .inProgress
        activateTask(index: WorkshopTaskID.w01UnderstandMission.index)
    }

    private func refreshCurrentReadiness() {
        if state.needsMissionReview {
            state.currentDesignReady = false
            return
        }
        guard state.completionRecords[.w04CheckDesign] != nil else {
            if state.currentTaskID != .w04CheckDesign {
                state.currentDesignReady = false
            }
            return
        }
        let result = TaskEvaluator.validateDesign(state.snapshot)
        state.lastDesignValidation = result
        if !result.isSatisfied {
            state.currentDesignReady = false
            readinessNeedsRecheck = true
            return
        }
        // Craft is valid again, but do not auto-restore Continue until Check Again.
        if readinessNeedsRecheck {
            state.currentDesignReady = false
        } else {
            state.currentDesignReady = true
        }
    }
}
