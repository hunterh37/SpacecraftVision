import SwiftUI
import TaskGuideCore

/// Standalone demo for Workshop V2. Not connected to the Vision Pro application.
public struct TaskGuideDemoView: View {
    @State private var controller: TaskGuideController
    @State private var snapshot: CraftStateSnapshot
    @State private var selectedPart: String = EssentialPartID.probeCore.rawValue
    @State private var targetBounds: [GuidanceTargetID: CGRect] = [:]

    public init() {
        let snap = Self.referenceSnapshot
        _controller = State(initialValue: TaskGuideController(snapshot: snap))
        _snapshot = State(initialValue: snap)
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 20) {
            TaskBoardView(
                controller: controller,
                host: TaskBoardHostContext(
                    missionHeadline: "M1 · Hop",
                    missionDetails: "Reach apogee 1000–1200 m. Mass 450 kg · 12 parts · 20000 cr. Fuel fixed at 10%.",
                    showsOpenPartsAction: true,
                    showsGoToLaunchRangeAction: true
                ),
                onOpenParts: {},
                onGoToLaunchRange: {}
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("DEMO — Workshop Guide V2")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
                Text("Interaction sandbox for package tests. Not the shipping Workshop.")
                    .font(.caption).foregroundStyle(.secondary)

                GroupBox("Craft snapshot") {
                    Toggle("Empty essential parts", isOn: Binding(
                        get: { !snapshot.containsPartID(EssentialPartID.probeCore.rawValue) },
                        set: { empty in
                            snapshot = empty ? Self.emptySnapshot : Self.referenceSnapshot
                            controller.updateSnapshot(snapshot)
                        }
                    ))
                    Toggle("Launch blocker", isOn: Binding(
                        get: { !snapshot.launchBlockers.isEmpty },
                        set: { blocked in
                            snapshot.launchBlockers = blocked ? ["Over budget"] : []
                            controller.updateSnapshot(snapshot)
                        }
                    ))
                    Slider(value: Binding(
                        get: { snapshot.thrustToWeightSL },
                        set: { snapshot.thrustToWeightSL = $0; controller.updateSnapshot(snapshot) }
                    ), in: 0.2...2.0)
                    Text(String(format: "TWR %.2f", snapshot.thrustToWeightSL)).font(.caption.monospacedDigit())
                }

                GroupBox("W02 selection events") {
                    Picker("Part", selection: $selectedPart) {
                        ForEach(EssentialPartID.allCases, id: \.rawValue) { part in
                            Text(part.displayName).tag(part.rawValue)
                        }
                    }
                    Button("Select part (event)") {
                        controller.noteComponentSelection(partID: selectedPart)
                    }
                }

                GroupBox("W03 scale event") {
                    Button("User toggle tabletop") {
                        snapshot.workshopTabletop.toggle()
                        controller.updateSnapshot(snapshot)
                        controller.noteTabletopScaleChanged(newValue: snapshot.workshopTabletop, userInitiated: true)
                    }
                }

                demoTargets
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(20)
        .coordinateSpace(name: "TaskGuideDemo")
        .onPreferenceChange(GuidanceTargetBoundsKey.self) { targetBounds = $0 }
        .overlay {
            GuidanceHighlightOverlay(activeID: controller.displayedTargetID, bounds: targetBounds)
        }
    }

    private var demoTargets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mission area").padding(8).background(.white.opacity(0.7)).guidanceTarget(.missionBrief)
            Text("Parts stack").padding(8).background(.white.opacity(0.7)).guidanceTarget(.partsStack)
            Text("Tabletop toggle").padding(8).background(.white.opacity(0.7)).guidanceTarget(.tabletopToggle)
            Text("Stat board").padding(8).background(.white.opacity(0.7)).guidanceTarget(.statBoard)
        }
    }

    private static var referenceSnapshot: CraftStateSnapshot {
        CraftStateSnapshot(
            missionID: "M1",
            partIDs: EssentialPartID.allCases.map(\.rawValue),
            launchBlockers: [],
            thrustToWeightSL: 1.4,
            wetMass: 200, massCap: 450,
            cost: 18_700, budget: 20_000,
            partCount: 11, partCap: 12,
            workshopTabletop: false
        )
    }

    private static var emptySnapshot: CraftStateSnapshot {
        CraftStateSnapshot(
            missionID: "M1",
            partIDs: [],
            launchBlockers: ["No command part"],
            thrustToWeightSL: 0,
            wetMass: 0, massCap: 450,
            cost: 0, budget: 20_000,
            partCount: 0, partCap: 12,
            workshopTabletop: false
        )
    }
}

#Preview("Workshop Guide Demo") {
    TaskGuideDemoView()
}
