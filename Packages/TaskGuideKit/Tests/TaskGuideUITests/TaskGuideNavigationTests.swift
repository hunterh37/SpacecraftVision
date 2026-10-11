import XCTest
import TaskGuideCore
@testable import TaskGuideUI

@MainActor
final class TaskGuideNavigationTests: XCTestCase {

    func testReviewingCompletedTaskDoesNotRewindProgress() {
        let controller = TaskGuideController(snapshot: .DemoFixture.launchReady.snapshot)
        controller.startBuild()
        controller.acknowledgeCurrent()
        controller.acknowledgeCurrent()
        XCTAssertEqual(controller.state.sessionPhase, .buildComplete)
        XCTAssertEqual(controller.state.completedTaskCount, 4)

        controller.focusTask(index: 2)
        XCTAssertEqual(controller.reviewTaskIndex, 2)
        XCTAssertEqual(controller.state.completedTaskCount, 4)
        XCTAssertEqual(controller.state.sessionPhase, .buildComplete)
    }

    func testReturnToCurrentTaskClearsReviewFocus() {
        let controller = TaskGuideController(snapshot: .DemoFixture.partial.snapshot)
        controller.startBuild()
        controller.acknowledgeCurrent()
        // Task 2 current; review task 1
        controller.focusTask(index: 1)
        XCTAssertEqual(controller.reviewTaskIndex, 1)
        XCTAssertEqual(controller.state.currentTaskIndex, 2)

        controller.returnToLive()
        XCTAssertNil(controller.reviewTaskIndex)
        XCTAssertEqual(controller.state.currentTaskIndex, 2)
        XCTAssertEqual(controller.state.sessionPhase, .inProgress)
    }

    func testReturnToCompletionClearsReviewFocus() {
        let controller = TaskGuideController(snapshot: .DemoFixture.launchReady.snapshot)
        controller.startBuild()
        controller.acknowledgeCurrent()
        controller.acknowledgeCurrent()
        XCTAssertEqual(controller.state.sessionPhase, .buildComplete)

        controller.goBack()
        XCTAssertEqual(controller.reviewTaskIndex, 4)

        controller.returnToLive()
        XCTAssertNil(controller.reviewTaskIndex)
        XCTAssertEqual(controller.state.sessionPhase, .buildComplete)
        XCTAssertNil(controller.displayedTargetID)
    }

    func testBackDoesNotResetGuideProgress() {
        let controller = TaskGuideController(snapshot: .DemoFixture.partial.snapshot)
        controller.startBuild()
        controller.acknowledgeCurrent()
        controller.acknowledgeCurrent()
        XCTAssertEqual(controller.state.currentTaskIndex, 3)
        XCTAssertEqual(controller.state.completedTaskCount, 2)

        controller.goBack()
        XCTAssertEqual(controller.reviewTaskIndex, 2)
        XCTAssertEqual(controller.state.completedTaskCount, 2)
        XCTAssertEqual(controller.state.currentTaskIndex, 3)

        controller.goBack()
        XCTAssertEqual(controller.reviewTaskIndex, 1)
        XCTAssertEqual(controller.state.completedTaskCount, 2)
    }

    func testExitClosesGuidanceWithoutMutatingSnapshot() {
        let snapshot = CraftStateSnapshot.DemoFixture.partial.snapshot
        let controller = TaskGuideController(snapshot: snapshot)
        controller.startBuild()
        controller.acknowledgeCurrent()
        let token = controller.state.snapshotMutationToken

        controller.exitGuide()
        XCTAssertEqual(controller.state.sessionPhase, .exited)
        XCTAssertEqual(controller.state.snapshot, snapshot)
        XCTAssertEqual(controller.state.snapshotMutationToken, token)
        XCTAssertNil(controller.displayedTargetID)
    }

    func testResetGuideClearsProgressOnly() {
        let snapshot = CraftStateSnapshot.DemoFixture.launchReady.snapshot
        let controller = TaskGuideController(snapshot: snapshot)
        controller.startBuild()
        controller.acknowledgeCurrent()
        let token = controller.state.snapshotMutationToken

        controller.resetGuide()
        XCTAssertEqual(controller.state.sessionPhase, .overview)
        XCTAssertTrue(controller.state.completionRecords.isEmpty)
        XCTAssertEqual(controller.state.snapshot, snapshot)
        XCTAssertEqual(controller.state.snapshotMutationToken, token)
        XCTAssertNil(controller.reviewTaskIndex)
    }
}
