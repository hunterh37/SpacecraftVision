import XCTest
@testable import TaskGuideCore

final class TaskGuideCoreTests: XCTestCase {

    // 1. New guide starts with zero acknowledged manual tasks.
    func testNewGuideStartsWithZeroAcknowledgedManualTasks() {
        let engine = TaskGuideEngine(snapshot: .DemoFixture.launchReady.snapshot)
        XCTAssertEqual(engine.state.sessionPhase, .overview)
        XCTAssertTrue(engine.state.completionRecords.isEmpty)
        XCTAssertEqual(engine.state.completedTaskCount, 0)

        let manualIDs = BuildMissionV0.tasks
            .filter { $0.completionKind == .manualAcknowledgment }
            .map(\.id)
        for id in manualIDs {
            XCTAssertNil(engine.state.completionRecords[id])
        }
    }

    // 2. Manual tasks cannot complete without acknowledgment.
    func testManualTasksCannotCompleteWithoutAcknowledgment() throws {
        let engine = TaskGuideEngine(snapshot: .DemoFixture.launchReady.snapshot)
        engine.startBuild()

        let task1 = try XCTUnwrap(BuildMissionV0.task(at: 1))
        XCTAssertEqual(engine.state.currentTaskIndex, 1)
        XCTAssertEqual(engine.state.status(for: task1), .current)
        XCTAssertNil(engine.state.completionRecords[task1.id])

        // Updating snapshot must not acknowledge manual tasks.
        engine.updateSnapshot(.DemoFixture.launchReady.snapshot)
        XCTAssertNil(engine.state.completionRecords[task1.id])
        XCTAssertEqual(engine.state.currentTaskIndex, 1)
    }

    // 3. Missing essential parts prevent Task 3 completion.
    func testMissingEssentialPartsPreventTask3Completion() throws {
        let engine = TaskGuideEngine(snapshot: .DemoFixture.partial.snapshot)
        engine.startBuild()
        engine.acknowledgeCurrent() // Task 1
        engine.acknowledgeCurrent() // Task 2

        let task3 = try XCTUnwrap(BuildMissionV0.task(at: 3))
        XCTAssertEqual(engine.state.currentTaskIndex, 3)
        XCTAssertNil(engine.state.completionRecords[task3.id])

        let validation = TaskEvaluator.validateComponents(engine.state.snapshot)
        XCTAssertFalse(validation.isSatisfied)
        XCTAssertTrue(validation.missingParts.contains(.fuelTankS))
        XCTAssertTrue(validation.missingParts.contains(.engineLiquidSmall))
    }

    // 4. An already-complete reference craft satisfies component validation.
    func testReferenceCraftSatisfiesComponentValidation() throws {
        let snapshot = CraftStateSnapshot.DemoFixture.launchReady.snapshot
        let result = TaskEvaluator.validateComponents(snapshot)
        XCTAssertTrue(result.isSatisfied)
        XCTAssertTrue(result.missingParts.isEmpty)

        let engine = TaskGuideEngine(snapshot: snapshot)
        engine.startBuild()
        engine.acknowledgeCurrent()
        engine.acknowledgeCurrent()

        let task3 = try XCTUnwrap(BuildMissionV0.task(at: 3))
        XCTAssertEqual(engine.state.completionRecords[task3.id], .alreadySatisfied)
    }

    // 5. A launch blocker prevents Task 4 completion.
    func testLaunchBlockerPreventsTask4Completion() throws {
        let engine = TaskGuideEngine(snapshot: .DemoFixture.fullyAssembledBlocked.snapshot)
        advanceToTask4(engine)

        let task4 = try XCTUnwrap(BuildMissionV0.task(at: 4))
        XCTAssertEqual(engine.state.currentTaskIndex, 4)
        XCTAssertNil(engine.state.completionRecords[task4.id])

        let preflight = TaskEvaluator.validatePreflight(engine.state.snapshot)
        XCTAssertFalse(preflight.isSatisfied)
        XCTAssertFalse(preflight.launchBlockers.isEmpty)
    }

    // 6. TWR at or below 1.0 prevents launch-readiness completion.
    func testTWRAtOrBelowOnePreventsLaunchReadiness() throws {
        let atOne = CraftStateSnapshot(
            partIDs: EssentialPartID.allCases.map(\.rawValue),
            launchBlockers: [],
            thrustToWeightSL: 1.0
        )
        XCTAssertFalse(TaskEvaluator.validatePreflight(atOne).isSatisfied)
        XCTAssertFalse(TaskEvaluator.validatePreflight(atOne).twrMeetsRequirement)

        let below = CraftStateSnapshot(
            partIDs: EssentialPartID.allCases.map(\.rawValue),
            launchBlockers: [],
            thrustToWeightSL: 0.8
        )
        let engine = TaskGuideEngine(snapshot: below)
        advanceToTask4(engine)

        let task4 = try XCTUnwrap(BuildMissionV0.task(at: 4))
        XCTAssertNil(engine.state.completionRecords[task4.id])
        XCTAssertEqual(engine.state.currentTaskIndex, 4)
    }

    // 7. A valid snapshot satisfies launch-readiness validation.
    func testValidSnapshotSatisfiesLaunchReadiness() throws {
        let snapshot = CraftStateSnapshot.DemoFixture.launchReady.snapshot
        let result = TaskEvaluator.validatePreflight(snapshot)
        XCTAssertTrue(result.isSatisfied)
        XCTAssertTrue(result.twrMeetsRequirement)
        XCTAssertTrue(result.launchBlockers.isEmpty)
        XCTAssertTrue(result.missingParts.isEmpty)

        let engine = TaskGuideEngine(snapshot: snapshot)
        engine.startBuild()
        engine.acknowledgeCurrent()
        engine.acknowledgeCurrent()

        XCTAssertEqual(engine.state.sessionPhase, .buildComplete)
        XCTAssertEqual(engine.state.completedTaskCount, 4)
        let task4 = try XCTUnwrap(BuildMissionV0.task(at: 4))
        XCTAssertNotNil(engine.state.completionRecords[task4.id])
    }

    // 8. Reset Guide does not mutate the input craft snapshot.
    func testResetGuideDoesNotMutateSnapshot() {
        let snapshot = CraftStateSnapshot.DemoFixture.partial.snapshot
        let engine = TaskGuideEngine(snapshot: snapshot)
        engine.startBuild()
        engine.acknowledgeCurrent()

        let tokenBefore = engine.state.snapshotMutationToken
        let snapshotBefore = engine.state.snapshot

        engine.resetGuide()

        XCTAssertEqual(engine.state.snapshot, snapshotBefore)
        XCTAssertEqual(engine.state.snapshotMutationToken, tokenBefore)
        XCTAssertEqual(engine.state.sessionPhase, .overview)
        XCTAssertTrue(engine.state.completionRecords.isEmpty)
        XCTAssertEqual(engine.state.completedTaskCount, 0)
    }

    // 9. Progress never exceeds the total number of tasks.
    func testProgressNeverExceedsTotalTasks() {
        let engine = TaskGuideEngine(snapshot: .DemoFixture.launchReady.snapshot)
        engine.startBuild()
        engine.acknowledgeCurrent()
        engine.acknowledgeCurrent()

        XCTAssertLessThanOrEqual(engine.state.completedTaskCount, BuildMissionV0.taskCount)
        XCTAssertEqual(engine.state.completedTaskCount, 4)
        XCTAssertEqual(engine.state.progressLabel, "4/4")

        // Extra acknowledgments / updates must not inflate progress.
        engine.acknowledgeCurrent()
        engine.updateSnapshot(.DemoFixture.launchReady.snapshot)
        XCTAssertEqual(engine.state.completedTaskCount, 4)
        XCTAssertLessThanOrEqual(engine.state.completionRecords.count, BuildMissionV0.taskCount)
    }

    // 10. Launch and Space are not represented as completed implementations.
    func testLaunchAndSpaceNotCompletedImplementations() {
        XCTAssertTrue(LearningPhase.build.isImplemented)
        XCTAssertFalse(LearningPhase.launch.isImplemented)
        XCTAssertFalse(LearningPhase.space.isImplemented)
        XCTAssertEqual(LearningPhase.launch.comingLaterLabel, "Coming later")
        XCTAssertEqual(LearningPhase.space.comingLaterLabel, "Coming later")
        XCTAssertNil(LearningPhase.build.comingLaterLabel)

        let engine = TaskGuideEngine(snapshot: .DemoFixture.launchReady.snapshot)
        engine.startBuild()
        engine.acknowledgeCurrent()
        engine.acknowledgeCurrent()
        XCTAssertEqual(engine.state.sessionPhase, .buildComplete)
        // Build completion must not mark Launch/Space as implemented workflows.
        XCTAssertFalse(LearningPhase.launch.isImplemented)
        XCTAssertFalse(LearningPhase.space.isImplemented)
    }

    // MARK: - Helpers

    private func advanceToTask4(_ engine: TaskGuideEngine) {
        engine.startBuild()
        engine.acknowledgeCurrent()
        engine.acknowledgeCurrent()
        // Task 3 auto-completes when components are present (blocked / low-TWR fixtures).
        XCTAssertEqual(engine.state.currentTaskIndex, 4, "Expected to reach Task 4 with components present")
    }
}
