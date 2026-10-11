import SwiftUI
import TaskGuideCore

/// Compact floating task board for the BUILD V0 guided mission.
public struct TaskBoardView: View {
    var controller: TaskGuideController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let panelWidth: CGFloat = 380

    public init(controller: TaskGuideController) {
        self.controller = controller
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
        .accessibilityLabel("Task guide")
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(BuildMissionV0.boardHeader)
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text(BuildMissionV0.missionTitle)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var phaseRoadmap: some View {
        HStack(spacing: 8) {
            ForEach(LearningPhase.allCases) { phase in
                VStack(spacing: 4) {
                    Text(phase.title)
                        .font(.caption.weight(phase == .build ? .semibold : .regular))
                        .foregroundStyle(phase == .build ? Color.primary : Color.secondary)
                    if let label = phase.comingLaterLabel {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(controller.state.isBuildPhaseComplete ? "Complete" : "Active")
                            .font(.caption2)
                            .foregroundStyle(controller.state.isBuildPhaseComplete ? Color.green : Color.accentColor)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(phase == .build ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(phaseAccessibilityLabel(phase))
            }
        }
    }

    private func phaseAccessibilityLabel(_ phase: LearningPhase) -> String {
        if phase.isImplemented {
            return "\(phase.title) phase, \(controller.state.isBuildPhaseComplete ? "complete" : "active")"
        }
        return "\(phase.title) phase, Coming later"
    }

    private var buildProgress: some View {
        HStack {
            Text("Build progress")
                .font(.subheadline.weight(.medium))
            Spacer()
            Text(controller.state.progressLabel)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .accessibilityLabel("Build progress \(controller.state.progressLabel)")
        }
    }

    private var taskList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(BuildMissionV0.tasks) { task in
                taskRow(task)
            }
        }
    }

    private func taskRow(_ task: BuildTaskDefinition) -> some View {
        let status = controller.state.status(for: task)
        let isFocused = controller.displayedTask?.id == task.id
            && controller.state.sessionPhase != .overview
            && controller.state.sessionPhase != .exited

        return Button {
            controller.focusTask(index: task.index)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                statusGlyph(status)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Task \(task.index) · \(task.title)")
                        .font(.subheadline.weight(isFocused ? .semibold : .regular))
                        .foregroundStyle(foreground(for: status, focused: isFocused))
                    Text(status.accessibilityLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if case .blocked(let reason) = status {
                        Text(reason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if case .completed(let record) = status, record == .alreadySatisfied {
                        Text("Already satisfied — present before you started this step.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isFocused ? Color.accentColor.opacity(0.14) : Color.clear)
            )
            .opacity(opacity(for: status, focused: isFocused))
        }
        .buttonStyle(.plain)
        .disabled({
            switch status {
            case .blocked, .notStarted: return true
            case .current, .completed: return false
            }
        }())
        .accessibilityLabel("Task \(task.index), \(task.title), \(status.accessibilityLabel)")
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch controller.state.sessionPhase {
            case .overview:
                Text("Prepare and inspect a rocket through four guided Build steps.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .exited:
                Text("Guide exited. Progress is kept until you reset.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .buildComplete:
                Text(BuildMissionV0.buildCompleteMessage)
                    .font(.subheadline.weight(.medium))
                Text("Launch and Space task guidance are Coming later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .inProgress:
                if let task = controller.displayedTask {
                    Text(task.title)
                        .font(.headline)
                    Text(task.instruction)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    validationDetail(for: task)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: controller.state.sessionPhase)
    }

    @ViewBuilder
    private func validationDetail(for task: BuildTaskDefinition) -> some View {
        switch task.completionKind {
        case .manualAcknowledgment:
            EmptyView()
        case .automaticCraftValidation:
            let result = controller.state.componentValidation
            Text(result.summary)
                .font(.caption)
                .foregroundStyle(result.isSatisfied ? Color.green : Color.orange)
        case .automaticPreflightValidation:
            let result = controller.state.preflightValidation
            Text(result.summary)
                .font(.caption)
                .foregroundStyle(result.isSatisfied ? Color.green : Color.orange)
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            primaryAction
            HStack(spacing: 8) {
                Button("Back") { controller.goBack() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!canGoBack)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Back")

                Button("Exit Guide") { controller.exitGuide() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Exit Guide")
            }

            Button("Reset Guide") { controller.resetGuide() }
                .buttonStyle(.borderless)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityHint("Resets task guide progress only. Does not change the rocket.")
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch controller.state.sessionPhase {
        case .overview, .exited:
            Button(BuildMissionV0.startActionLabel) { controller.startBuild() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(BuildMissionV0.startActionLabel)
        case .buildComplete:
            EmptyView()
        case .inProgress:
            if let task = controller.state.currentTask,
               controller.reviewTaskIndex == nil,
               task.completionKind == .manualAcknowledgment,
               let label = task.acknowledgmentLabel
            {
                Button(label) { controller.acknowledgeCurrent() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(label)
            } else if controller.reviewTaskIndex != nil {
                Button(controller.state.sessionPhase == .buildComplete ? "Back to Completion" : "Return to Current Task") {
                    if controller.state.sessionPhase == .buildComplete {
                        // Clear review to show completion message via displayedTask fallback.
                        controller.focusTask(index: BuildMissionV0.taskCount)
                        // focusTask on completed keeps review; use reset of review by focusing nil path:
                        controller.goBack() // no — use explicit clear
                    }
                    if let current = controller.state.currentTaskIndex {
                        controller.focusTask(index: current)
                    } else {
                        // buildComplete: clear review by focusing last then we need clearReview
                        controller.focusTask(index: BuildMissionV0.taskCount)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            } else if let task = controller.state.currentTask, task.completionKind != .manualAcknowledgment {
                Text("Waiting for automatic validation…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Waiting for automatic validation")
            }
        }
    }

    private var canGoBack: Bool {
        switch controller.state.sessionPhase {
        case .inProgress, .buildComplete:
            return true
        case .overview, .exited:
            return controller.reviewTaskIndex != nil
        }
    }

    // MARK: - Styling helpers

    private func statusGlyph(_ status: TaskItemStatus) -> some View {
        Group {
            switch status {
            case .notStarted:
                Image(systemName: "circle")
            case .current:
                Image(systemName: "circle.inset.filled")
                    .foregroundStyle(Color.accentColor)
            case .completed(let record):
                Image(systemName: record == .alreadySatisfied ? "checkmark.circle" : "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .blocked:
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }

    private func foreground(for status: TaskItemStatus, focused: Bool) -> Color {
        switch status {
        case .blocked: return .secondary
        case .completed: return focused ? .primary : .secondary
        case .current: return .primary
        case .notStarted: return .secondary
        }
    }

    private func opacity(for status: TaskItemStatus, focused: Bool) -> Double {
        switch status {
        case .completed where !focused: return 0.72
        case .blocked: return 0.7
        default: return 1
        }
    }
}
