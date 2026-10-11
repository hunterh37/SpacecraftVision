import SwiftUI
import TaskGuideCore

public struct TaskBoardView: View {
    var controller: TaskGuideController
    var host: TaskBoardHostContext
    var onOpenParts: (() -> Void)?
    var onGoToLaunchRange: (() -> Void)?
    var onExitGuide: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let panelWidth: CGFloat = 380

    public init(
        controller: TaskGuideController,
        host: TaskBoardHostContext = .demo,
        onOpenParts: (() -> Void)? = nil,
        onGoToLaunchRange: (() -> Void)? = nil,
        onExitGuide: (() -> Void)? = nil
    ) {
        self.controller = controller
        self.host = host
        self.onOpenParts = onOpenParts
        self.onGoToLaunchRange = onGoToLaunchRange
        self.onExitGuide = onExitGuide
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            phaseRoadmap
            buildProgress
            taskList
            detailSection
            controls
        }
        .padding(16)
        .frame(width: panelWidth, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workshop task guide")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WorkshopMissionV2.boardHeader)
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text(WorkshopMissionV2.missionTitle)
                .font(.title3.weight(.semibold))
        }
    }

    private var phaseRoadmap: some View {
        HStack(spacing: 8) {
            ForEach(LearningPhase.allCases) { phase in
                VStack(spacing: 4) {
                    Text(phase.title)
                        .font(.caption.weight(phase == .workshop ? .semibold : .regular))
                    if let label = phase.comingLaterLabel {
                        Text(label).font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text(controller.state.allTasksHistoricallyComplete ? "Complete" : "Active")
                            .font(.caption2)
                            .foregroundStyle(controller.state.allTasksHistoricallyComplete ? Color.green : Color.accentColor)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(phase == .workshop ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                )
            }
        }
    }

    private var buildProgress: some View {
        HStack {
            Text("Workshop progress")
                .font(.subheadline.weight(.medium))
            Spacer()
            Text(controller.state.progressLabel)
                .font(.subheadline.monospacedDigit().weight(.semibold))
        }
    }

    private var taskList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(WorkshopTaskID.allCases) { task in
                taskRow(task)
            }
        }
    }

    private func taskRow(_ task: WorkshopTaskID) -> some View {
        let status = controller.state.status(for: task)
        let focused = isFocused(task)
        return Button { controller.focusTask(index: task.index) } label: {
            HStack(alignment: .top, spacing: 10) {
                statusGlyph(status)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(task.rawValue) · \(task.title)")
                        .font(.subheadline.weight(focused ? .semibold : .regular))
                        .foregroundStyle(focused || status.isCompleted == false && status.accessibilityLabel == "Current" ? Color.primary : Color.secondary)
                    Text(status.accessibilityLabel).font(.caption2).foregroundStyle(.secondary)
                    if case .blocked(let reason) = status {
                        Text(reason).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(focused ? Color.accentColor.opacity(0.14) : Color.clear)
            )
            .opacity(status.isCompleted && !focused ? 0.72 : 1)
        }
        .buttonStyle(.plain)
        .disabled({
            switch status {
            case .blocked, .notStarted: return true
            case .current, .completed: return false
            }
        }())
    }

    private func isFocused(_ task: WorkshopTaskID) -> Bool {
        if let review = controller.reviewTaskIndex { return review == task.index }
        return controller.state.sessionPhase == .inProgress && controller.state.currentTaskIndex == task.index
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch controller.state.sessionPhase {
            case .overview:
                Text("Inspect the current mission, identify essential components, explore scale, and check design readiness.")
                    .font(.subheadline).foregroundStyle(.secondary)
            case .exited:
                Text("Guide exited. Progress is kept until you reset.")
                    .font(.subheadline).foregroundStyle(.secondary)
            case .workshopComplete:
                if controller.isReviewing, let task = controller.displayedTaskID {
                    taskDetail(task)
                } else {
                    completionDetail
                }
            case .inProgress:
                if let task = controller.displayedTaskID {
                    taskDetail(task)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: controller.state.sessionPhase)
    }

    private var completionDetail: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(WorkshopMissionV2.completeTitle).font(.subheadline.weight(.semibold))
            Text(WorkshopMissionV2.completeSubtitle).font(.caption).foregroundStyle(.secondary)
            if controller.state.currentDesignReady {
                Text("Current rocket passes the design checks.")
                    .font(.caption).foregroundStyle(.green)
            } else {
                Text("Current rocket needs another design check before Continue to Launch Range.")
                    .font(.caption).foregroundStyle(.orange)
                if let summary = controller.state.lastDesignValidation?.summary {
                    Text(summary).font(.caption2).foregroundStyle(.secondary)
                }
            }
            if let note = host.readinessNote {
                Text(note).font(.caption2).foregroundStyle(.secondary)
            }
            Text("Launch and Space learning tasks are Coming later.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func taskDetail(_ task: WorkshopTaskID) -> some View {
        if controller.isReviewing {
            Text("Reviewing \(task.rawValue)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        Text(task.title).font(.headline)
        Text(task.instruction).font(.subheadline).foregroundStyle(.secondary)

        switch task {
        case .w01UnderstandMission:
            if let headline = host.missionHeadline {
                Text(headline).font(.caption.weight(.semibold))
            }
            if let details = host.missionDetails {
                Text(details).font(.caption).foregroundStyle(.secondary)
            }
            if controller.state.needsMissionReview {
                Text("Mission changed. Review the new mission before continuing.")
                    .font(.caption).foregroundStyle(.orange)
            }
        case .w02IdentifyComponents:
            w02Detail
        case .w03ExploreScale:
            Text("Life-size shows the rocket at 1:1 on the hangar pad. Tabletop scale places a miniature on the workbench.")
                .font(.caption).foregroundStyle(.secondary)
        case .w04CheckDesign:
            w04Detail
        }
    }

    private var w02Detail: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let expected = controller.state.expectedComponent {
                Text("Select: \(expected.displayName)")
                    .font(.caption.weight(.semibold))
            }
            Text("Progress \(controller.state.completedComponentSubsteps)/\(WorkshopMissionV2.componentOrder.count)")
                .font(.caption2).foregroundStyle(.secondary)
            let missing = TaskEvaluator.validateComponents(controller.state.snapshot)
            if !missing.isSatisfied {
                Text(missing.summary).font(.caption).foregroundStyle(.orange)
            }
            if let explanation = controller.state.lastComponentExplanation {
                Text(explanation).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var w04Detail: some View {
        let snap = controller.state.snapshot
        return VStack(alignment: .leading, spacing: 4) {
            Text(WorkshopMissionV2.twrExplanation).font(.caption).foregroundStyle(.secondary)
            Text(String(
                format: "Wet mass %.0f / %.0f kg · Cost %d / %d cr · Parts %d / %d · TWR %.2f",
                snap.wetMass, snap.massCap, snap.cost, snap.budget, snap.partCount, snap.partCap, snap.thrustToWeightSL
            ))
            .font(.caption.monospacedDigit())
            if snap.launchBlockers.isEmpty {
                Text("Blockers: none").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("Blockers: \(snap.launchBlockers.joined(separator: "; "))")
                    .font(.caption2).foregroundStyle(.orange)
            }
            if let result = controller.state.lastDesignValidation, !result.isSatisfied {
                Text(result.summary).font(.caption).foregroundStyle(.orange)
                Text("Use Parts and the stat board to correct the craft, then check again.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            primaryAction
            secondaryActions
            HStack(spacing: 8) {
                Button("Back") { controller.goBack() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!canGoBack)
                    .frame(maxWidth: .infinity)
                Button("Exit Guide") {
                    controller.exitGuide()
                    onExitGuide?()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
            Button("Reset Guide") { controller.resetGuide() }
                .buttonStyle(.borderless)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityHint("Resets guide progress only. Does not change the rocket.")
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        if controller.isReviewing {
            Button(controller.state.sessionPhase == .workshopComplete ? "Return to Completion" : "Return to Current Task") {
                controller.returnToLive()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        } else {
            switch controller.state.sessionPhase {
            case .overview, .exited:
                Button(WorkshopMissionV2.startActionLabel) { controller.startGuide() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            case .workshopComplete:
                if controller.state.canContinueToLaunchRange, host.showsGoToLaunchRangeAction, let go = onGoToLaunchRange {
                    Button(WorkshopMissionV2.continueToRangeLabel, action: go)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                } else if controller.state.allTasksHistoricallyComplete {
                    Button(WorkshopMissionV2.checkAgainLabel) { controller.checkDesign() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                }
            case .inProgress:
                if let task = controller.state.currentTaskID {
                    switch task {
                    case .w01UnderstandMission:
                        Button(WorkshopMissionV2.understandLabel) { controller.acknowledgeMission() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                    case .w02IdentifyComponents, .w03ExploreScale:
                        Text("Waiting for your action in the Parts window…")
                            .font(.caption).foregroundStyle(.secondary)
                    case .w04CheckDesign:
                        let label = controller.state.lastDesignValidation == nil
                            ? WorkshopMissionV2.checkDesignLabel
                            : WorkshopMissionV2.checkAgainLabel
                        Button(label) { controller.checkDesign() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var secondaryActions: some View {
        if shouldOfferOpenParts, let open = onOpenParts {
            Button(WorkshopMissionV2.openPartsLabel, action: open)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
    }

    private var shouldOfferOpenParts: Bool {
        guard host.showsOpenPartsAction, !controller.isReviewing else { return false }
        guard controller.state.sessionPhase == .inProgress,
              let task = controller.state.currentTaskID
        else { return false }
        return task == .w02IdentifyComponents || task == .w03ExploreScale || task == .w04CheckDesign
    }

    private var canGoBack: Bool {
        if controller.isReviewing { return true }
        switch controller.state.sessionPhase {
        case .inProgress, .workshopComplete: return true
        case .overview, .exited: return false
        }
    }

    private func statusGlyph(_ status: TaskItemStatus) -> some View {
        Group {
            switch status {
            case .notStarted: Image(systemName: "circle")
            case .current: Image(systemName: "circle.inset.filled").foregroundStyle(Color.accentColor)
            case .completed: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .blocked: Image(systemName: "lock.fill").foregroundStyle(.secondary)
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}
