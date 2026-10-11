import XCTest
@testable import TaskGuideCore

/// Lifecycle-oriented engine tests supporting scene-transition integration rules.
final class WorkshopLifecycleTests: XCTestCase {

    private var ready: CraftStateSnapshot {
        CraftStateSnapshot(
            missionID: "M1",
            partIDs: EssentialPartID.allCases.map(\.rawValue),
            launchBlockers: [],
            thrustToWeightSL: 1.4,
            wetMass: 200, massCap: 450,
            cost: 10_000, budget: 20_000,
            partCount: 8, partCap: 12,
            workshopTabletop: false
        )
    }

    func testExitPreservesProgressForReentry() {
        let engine = WorkshopGuideEngine(snapshot: ready)
        engine.startGuide()
        engine.acknowledgeMission()
        engine.noteComponentSelection(partID: EssentialPartID.probeCore.rawValue)
        engine.exitGuide()
        XCTAssertEqual(engine.state.sessionPhase, .exited)
        XCTAssertEqual(engine.state.completedComponentSubsteps, 1)
        engine.startGuide()
        XCTAssertEqual(engine.state.currentTaskID, .w02IdentifyComponents)
        XCTAssertEqual(engine.state.completionRecords[.w01UnderstandMission], .acknowledged)
    }

    func testResetDoesNotClearBoundMissionSnapshotFields() {
        let engine = WorkshopGuideEngine(snapshot: ready)
        engine.startGuide()
        engine.acknowledgeMission()
        engine.resetGuide()
        XCTAssertEqual(engine.state.snapshot.missionID, "M1")
        XCTAssertEqual(engine.state.snapshot.partIDs, ready.partIDs)
    }
}
