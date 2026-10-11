import XCTest
import TaskGuideCore
@testable import TaskGuideUI

@MainActor
final class WorkshopNavigationTests: XCTestCase {
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

    // 17
    func testCompletedTasksCanBeReviewedWithoutRewinding() {
        let c = TaskGuideController(snapshot: ready)
        completeAll(c)
        XCTAssertEqual(c.state.sessionPhase, .workshopComplete)
        c.focusTask(index: 2)
        XCTAssertEqual(c.reviewTaskIndex, 2)
        XCTAssertEqual(c.state.completedTaskCount, 4)
        c.returnToLive()
        XCTAssertNil(c.reviewTaskIndex)
        XCTAssertEqual(c.state.sessionPhase, .workshopComplete)
    }

    // 16 (controller level)
    func testExitAndReentryViaController() {
        let c = TaskGuideController(snapshot: ready)
        c.startGuide()
        c.acknowledgeMission()
        c.exitGuide()
        c.startGuide()
        XCTAssertEqual(c.state.currentTaskID, .w02IdentifyComponents)
        XCTAssertEqual(c.state.completionRecords[.w01UnderstandMission], .acknowledged)
    }

    private func completeAll(_ c: TaskGuideController) {
        c.startGuide()
        c.acknowledgeMission()
        for part in WorkshopMissionV2.componentOrder {
            c.noteComponentSelection(partID: part.rawValue)
        }
        c.noteTabletopScaleChanged(newValue: true, userInitiated: true)
        c.checkDesign()
    }
}
