import XCTest
@testable import TaskGuideCore

final class WorkshopGuideTests: XCTestCase {

    private var ready: CraftStateSnapshot {
        CraftStateSnapshot(
            missionID: "M1",
            partIDs: EssentialPartID.allCases.map(\.rawValue) + ["nose-cone"],
            launchBlockers: [],
            thrustToWeightSL: 1.4,
            wetMass: 200, massCap: 450,
            cost: 18_700, budget: 20_000,
            partCount: 11, partCap: 12,
            workshopTabletop: false
        )
    }

    // 1
    func testInitialWorkshopGuideState() {
        let engine = WorkshopGuideEngine(snapshot: ready)
        XCTAssertEqual(engine.state.sessionPhase, .overview)
        XCTAssertTrue(engine.state.completionRecords.isEmpty)
        XCTAssertFalse(engine.state.currentDesignReady)
        XCTAssertEqual(engine.state.completedTaskCount, 0)
    }

    // 2
    func testMissionAcknowledgment() {
        let engine = WorkshopGuideEngine(snapshot: ready)
        engine.startGuide()
        XCTAssertEqual(engine.state.currentTaskID, .w01UnderstandMission)
        engine.acknowledgeMission()
        XCTAssertEqual(engine.state.completionRecords[.w01UnderstandMission], .acknowledged)
        XCTAssertEqual(engine.state.currentTaskID, .w02IdentifyComponents)
    }

    // 3 + 6
    func testW02RequiresRealSelectionEventsAndDoesNotAutoComplete() {
        let engine = WorkshopGuideEngine(snapshot: ready)
        engine.startGuide()
        engine.acknowledgeMission()
        XCTAssertEqual(engine.state.currentTaskID, .w02IdentifyComponents)
        XCTAssertNil(engine.state.completionRecords[.w02IdentifyComponents])
        // Snapshot already has parts — must not auto-complete.
        engine.updateSnapshot(ready)
        XCTAssertNil(engine.state.completionRecords[.w02IdentifyComponents])
    }

    // 4
    func testIncorrectSelectionDoesNotAdvanceW02() {
        let engine = WorkshopGuideEngine(snapshot: ready)
        engine.startGuide()
        engine.acknowledgeMission()
        engine.noteComponentSelection(partID: EssentialPartID.fuelTankS.rawValue) // wrong first
        XCTAssertEqual(engine.state.completedComponentSubsteps, 0)
        XCTAssertEqual(engine.state.expectedComponent, .probeCore)
    }

    // 5
    func testCorrectSelectionOrderAdvancesW02() {
        let engine = WorkshopGuideEngine(snapshot: ready)
        engine.startGuide()
        engine.acknowledgeMission()
        engine.noteComponentSelection(partID: EssentialPartID.probeCore.rawValue)
        XCTAssertEqual(engine.state.completedComponentSubsteps, 1)
        engine.noteComponentSelection(partID: EssentialPartID.fuelTankS.rawValue)
        XCTAssertEqual(engine.state.completedComponentSubsteps, 2)
        engine.noteComponentSelection(partID: EssentialPartID.engineLiquidSmall.rawValue)
        XCTAssertEqual(engine.state.completionRecords[.w02IdentifyComponents], .interacted)
        XCTAssertEqual(engine.state.currentTaskID, .w03ExploreScale)
    }

    // 7
    func testW03RequiresUserTriggeredScaleChange() {
        let engine = WorkshopGuideEngine(snapshot: ready)
        advanceToW03(engine)
        engine.noteTabletopScaleChanged(newValue: false, userInitiated: true) // same as start
        XCTAssertNil(engine.state.completionRecords[.w03ExploreScale])
        engine.noteTabletopScaleChanged(newValue: true, userInitiated: false) // programmatic
        XCTAssertNil(engine.state.completionRecords[.w03ExploreScale])
        engine.noteTabletopScaleChanged(newValue: true, userInitiated: true)
        XCTAssertEqual(engine.state.completionRecords[.w03ExploreScale], .interacted)
    }

    // 8
    func testW04DoesNotAutoCompleteBeforeCheckDesign() {
        let engine = WorkshopGuideEngine(snapshot: ready)
        advanceToW04(engine)
        engine.updateSnapshot(ready)
        XCTAssertNil(engine.state.completionRecords[.w04CheckDesign])
        XCTAssertFalse(engine.state.currentDesignReady)
    }

    // 9
    func testMissingPartsBlockValidation() {
        var snap = ready
        snap.partIDs = [EssentialPartID.probeCore.rawValue]
        let engine = WorkshopGuideEngine(snapshot: snap)
        advanceToW04(engine)
        engine.checkDesign()
        XCTAssertNil(engine.state.completionRecords[.w04CheckDesign])
        XCTAssertFalse(engine.state.currentDesignReady)
        XCTAssertFalse(engine.state.lastDesignValidation?.missingParts.isEmpty ?? true)
    }

    // 10
    func testLaunchBlockersBlockValidation() {
        var snap = ready
        snap.launchBlockers = ["Over budget"]
        let engine = WorkshopGuideEngine(snapshot: snap)
        advanceToW04(engine)
        engine.checkDesign()
        XCTAssertNil(engine.state.completionRecords[.w04CheckDesign])
        XCTAssertFalse(engine.state.currentDesignReady)
    }

    // 11
    func testTWRBlocksValidation() {
        var snap = ready
        snap.thrustToWeightSL = 1.0
        let engine = WorkshopGuideEngine(snapshot: snap)
        advanceToW04(engine)
        engine.checkDesign()
        XCTAssertNil(engine.state.completionRecords[.w04CheckDesign])
        snap.thrustToWeightSL = 0.9
        engine.updateSnapshot(snap)
        engine.checkDesign()
        XCTAssertNil(engine.state.completionRecords[.w04CheckDesign])
    }

    // 12
    func testValidStateAllowsCompletion() {
        let engine = WorkshopGuideEngine(snapshot: ready)
        advanceToW04(engine)
        engine.checkDesign()
        XCTAssertEqual(engine.state.completionRecords[.w04CheckDesign], .validated)
        XCTAssertTrue(engine.state.currentDesignReady)
        XCTAssertEqual(engine.state.sessionPhase, .workshopComplete)
        XCTAssertTrue(engine.state.canContinueToLaunchRange)
    }

    // 13
    func testPreviouslyValidCraftBecomingInvalidRemovesReadiness() {
        let engine = WorkshopGuideEngine(snapshot: ready)
        completeAll(engine)
        XCTAssertTrue(engine.state.currentDesignReady)
        var bad = ready
        bad.partIDs.removeAll { $0 == EssentialPartID.engineLiquidSmall.rawValue }
        engine.updateSnapshot(bad)
        XCTAssertEqual(engine.state.completionRecords[.w04CheckDesign], .validated) // historical
        XCTAssertFalse(engine.state.currentDesignReady)
        XCTAssertFalse(engine.state.canContinueToLaunchRange)
    }

    // 14
    func testRestoredValidCraftRequiresRenewedValidation() {
        let engine = WorkshopGuideEngine(snapshot: ready)
        completeAll(engine)
        var bad = ready
        bad.thrustToWeightSL = 0.5
        engine.updateSnapshot(bad)
        XCTAssertFalse(engine.state.currentDesignReady)
        engine.updateSnapshot(ready)
        // refreshCurrentReadiness auto-recomputes when W04 historically complete
        // Spec: "After corrective changes, require renewed explicit validation."
        // So we should NOT auto-restore readiness — only checkDesign should.
        // Adjust engine: when snapshot recovers, set currentDesignReady false until checkDesign.
        // Currently refreshCurrentReadiness sets true if valid. Fix engine + this test.
        XCTAssertFalse(engine.state.currentDesignReady, "Must require Check Again after recovery")
        engine.checkDesign()
        XCTAssertTrue(engine.state.currentDesignReady)
    }

    // 15
    func testMissionChangeInvalidatesMissionSpecificReadiness() {
        let engine = WorkshopGuideEngine(snapshot: ready)
        completeAll(engine)
        var m2 = ready
        m2.missionID = "M2"
        engine.updateSnapshot(m2)
        XCTAssertTrue(engine.state.needsMissionReview)
        XCTAssertNil(engine.state.completionRecords[.w01UnderstandMission])
        XCTAssertNil(engine.state.completionRecords[.w04CheckDesign])
        XCTAssertNotNil(engine.state.completionRecords[.w02IdentifyComponents])
        XCTAssertNotNil(engine.state.completionRecords[.w03ExploreScale])
        XCTAssertFalse(engine.state.canContinueToLaunchRange)
        XCTAssertEqual(engine.state.currentTaskID, .w01UnderstandMission)
    }

    // 16
    func testExitAndReentryPreserveProgress() {
        let engine = WorkshopGuideEngine(snapshot: ready)
        engine.startGuide()
        engine.acknowledgeMission()
        engine.exitGuide()
        XCTAssertEqual(engine.state.sessionPhase, .exited)
        XCTAssertEqual(engine.state.completionRecords[.w01UnderstandMission], .acknowledged)
        engine.startGuide()
        XCTAssertEqual(engine.state.sessionPhase, .inProgress)
        XCTAssertEqual(engine.state.currentTaskID, .w02IdentifyComponents)
    }

    // 18
    func testResetDoesNotMutateCraftSnapshot() {
        let engine = WorkshopGuideEngine(snapshot: ready)
        engine.startGuide()
        engine.acknowledgeMission()
        let token = engine.state.snapshotMutationToken
        let snap = engine.state.snapshot
        engine.resetGuide()
        XCTAssertEqual(engine.state.snapshot, snap)
        XCTAssertEqual(engine.state.snapshotMutationToken, token)
        XCTAssertTrue(engine.state.completionRecords.isEmpty)
    }

    // Helpers

    private func advanceToW03(_ engine: WorkshopGuideEngine) {
        engine.startGuide()
        engine.acknowledgeMission()
        for part in WorkshopMissionV2.componentOrder {
            engine.noteComponentSelection(partID: part.rawValue)
        }
        XCTAssertEqual(engine.state.currentTaskID, .w03ExploreScale)
    }

    private func advanceToW04(_ engine: WorkshopGuideEngine) {
        advanceToW03(engine)
        let flipped = !engine.state.snapshot.workshopTabletop
        engine.noteTabletopScaleChanged(newValue: flipped, userInitiated: true)
        XCTAssertEqual(engine.state.currentTaskID, .w04CheckDesign)
    }

    private func completeAll(_ engine: WorkshopGuideEngine) {
        advanceToW04(engine)
        engine.checkDesign()
        XCTAssertEqual(engine.state.sessionPhase, .workshopComplete)
    }
}
