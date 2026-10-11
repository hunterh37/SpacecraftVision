import SwiftUI
import TaskGuideCore

/// Standalone 2D demo of the BUILD task guide. Not connected to the Vision Pro application.
public struct TaskGuideDemoView: View {
    @State private var controller: TaskGuideController
    @State private var selectedFixture: CraftStateSnapshot.DemoFixture
    @State private var targetBounds: [GuidanceTargetID: CGRect] = [:]

    private let demoSpace = CoordinateSpace.named("TaskGuideDemo")

    public init(initialFixture: CraftStateSnapshot.DemoFixture = .launchReady) {
        let controller = TaskGuideController(snapshot: initialFixture.snapshot)
        _controller = State(initialValue: controller)
        _selectedFixture = State(initialValue: initialFixture)
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 20) {
            TaskBoardView(controller: controller)
                .frame(maxHeight: .infinity, alignment: .top)

            VStack(alignment: .leading, spacing: 14) {
                demoBanner
                fixtureControls
                demoWorkspace
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(20)
        .frame(minWidth: 960, minHeight: 640)
        .background(
            LinearGradient(
                colors: [Color(white: 0.95), Color(white: 0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .coordinateSpace(name: "TaskGuideDemo")
        .onPreferenceChange(GuidanceTargetBoundsKey.self) { targetBounds = $0 }
        .overlay {
            GuidanceHighlightOverlay(
                activeID: controller.displayedTargetID,
                bounds: targetBounds
            )
        }
        .overlay(alignment: .bottomLeading) {
            if let task = controller.displayedTask,
               controller.state.sessionPhase == .inProgress || controller.state.sessionPhase == .buildComplete
            {
                Text("Guidance: \(task.instruction)")
                    .font(.caption)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding()
                    .accessibilityLabel("Guidance instruction")
            }
        }
    }

    private var demoBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEMO — Task Guide Preview")
                .font(.caption.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(.orange)
            Text("Isolated SwiftUI preview. Not anchored to the Workshop 3D scene or the shipping app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var fixtureControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Demo craft snapshot (test input only)")
                .font(.subheadline.weight(.semibold))
            Text("These controls change the evaluation snapshot for this preview. They never modify the real application craft.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(CraftStateSnapshot.DemoFixture.allCases) { fixture in
                    Button {
                        selectedFixture = fixture
                        controller.updateSnapshot(fixture.snapshot)
                    } label: {
                        HStack {
                            Image(systemName: selectedFixture == fixture ? "circle.inset.filled" : "circle")
                            Text(fixture.title)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(fixture.title)
                    .accessibilityAddTraits(selectedFixture == fixture ? .isSelected : [])
                }
            }

            snapshotSummary
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var snapshotSummary: some View {
        let snap = controller.state.snapshot
        return VStack(alignment: .leading, spacing: 2) {
            Text("Parts: \(snap.partIDs.isEmpty ? "(none)" : snap.partIDs.joined(separator: ", "))")
            Text("Blockers: \(snap.launchBlockers.isEmpty ? "(none)" : snap.launchBlockers.joined(separator: "; "))")
            Text(String(format: "TWR SL: %.2f", snap.thrustToWeightSL))
        }
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)
    }

    private var demoWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            demoTargetCard(
                id: .missionBrief,
                title: "Mission Brief (representative)",
                body: "Objective: assemble a hop-capable rocket with command core, fuel, and engine. Mass and budget caps apply. This panel stands in for the real mission brief UI."
            )
            demoTargetCard(
                id: .partsPalette,
                title: "Parts Palette (representative)",
                body: "Command core · Fuel tank · Liquid rocket engine. Finding this area completes Task 2 in the demo; it does not open the real Parts window."
            )
            demoTargetCard(
                id: .craftAssembly,
                title: "Rocket Assembly (representative)",
                body: assemblyBody
            )
            demoTargetCard(
                id: .statBoard,
                title: "Stats / Preflight (representative)",
                body: preflightBody
            )
        }
    }

    private var assemblyBody: String {
        let result = controller.state.componentValidation
        if result.isSatisfied {
            return "Essential parts present: command core, fuel tank, liquid rocket engine."
        }
        return "Missing essential parts: \(result.missingDisplayNames.joined(separator: ", "))."
    }

    private var preflightBody: String {
        let result = controller.state.preflightValidation
        if result.isSatisfied {
            return "Mass / TWR / blockers look launch-ready in this demo snapshot."
        }
        return result.summary
    }

    private func demoTargetCard(id: GuidanceTargetID, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(body)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Target ID: \(id.rawValue)")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .guidanceTarget(id)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), guidance target \(id.rawValue)")
    }
}

#Preview("Task Guide Demo") {
    TaskGuideDemoView(initialFixture: .launchReady)
}
