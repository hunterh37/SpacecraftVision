import Foundation
import SpacecraftCore
import TaskGuideCore
import TaskGuideUI

enum TaskGuideBridge {
    static func snapshot(from model: AppModel) -> CraftStateSnapshot {
        let s = model.craft.stats()
        let m = model.mission
        return CraftStateSnapshot(
            missionID: m.id,
            partIDs: (model.craft.stack + model.craft.radial).map(\.partId),
            launchBlockers: model.blockers.map(\.title),
            thrustToWeightSL: s.twrSL,
            wetMass: s.wetMass,
            massCap: m.massCap,
            cost: s.cost,
            budget: m.budget,
            partCount: s.partCount,
            partCap: m.partCap,
            workshopTabletop: model.workshopTabletop
        )
    }

    static func hostContext(mission: Mission, controller: TaskGuideController) -> TaskBoardHostContext {
        TaskBoardHostContext(
            missionHeadline: "\(mission.id) · \(mission.title)",
            missionDetails: missionDetails(mission),
            readinessNote: readinessNote(controller),
            showsOpenPartsAction: true,
            showsGoToLaunchRangeAction: true
        )
    }

    static func missionDetails(_ mission: Mission) -> String {
        let goal: String
        switch mission.goal {
        case let .hop(lo, hi, pitch):
            if let pitch {
                goal = "Reach apogee \(Int(lo))–\(Int(hi)) m, land in the zone, keep pitch RMS under \(Int(pitch))°."
            } else {
                goal = "Reach apogee \(Int(lo))–\(Int(hi)) m and land in the zone."
            }
        case .gates:
            goal = "Fly through \(mission.course.gates.count) ring gates in order and cross the finish."
        case .climb, .capstone:
            goal = "Climb inside the corridor and cross the finish."
        }
        var lines = [
            goal,
            "Mass cap \(Int(mission.massCap)) kg · \(mission.partCap) parts · \(mission.budget) cr · \(Int(mission.energyCap)) Wh.",
        ]
        if let fuel = mission.fixedFuelLoad {
            lines.append("Fuel load fixed at \(Int((fuel * 100).rounded()))% for this mission.")
        }
        return lines.joined(separator: " ")
    }

    static func readinessNote(_ controller: TaskGuideController) -> String? {
        if controller.state.needsMissionReview {
            return "Mission changed. Review the new mission and check the design again."
        }
        if controller.state.allTasksHistoricallyComplete && !controller.state.currentDesignReady {
            return "Historical workshop checks remain, but the current rocket needs Check Again."
        }
        return nil
    }
}
