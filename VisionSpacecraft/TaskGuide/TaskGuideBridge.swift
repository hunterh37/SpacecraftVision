import Foundation
import SpacecraftCore
import TaskGuideCore
import TaskGuideUI

/// Maps live AppModel craft/mission state into TaskGuideKit inputs. No fixture data.
enum TaskGuideBridge {
    static func snapshot(craft: CraftDesign, blockers: [LaunchBlocker]) -> CraftStateSnapshot {
        let partIDs = (craft.stack + craft.radial).map(\.partId)
        return CraftStateSnapshot(
            partIDs: partIDs,
            launchBlockers: blockers.map(\.title),
            thrustToWeightSL: craft.stats().twrSL
        )
    }

    static func hostContext(mission: Mission, controller: TaskGuideController) -> TaskBoardHostContext {
        TaskBoardHostContext(
            missionHeadline: "\(mission.id) · \(mission.title)",
            missionDetails: missionDetails(mission),
            completionNote: completionNote(for: controller),
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
        }
        return [
            goal,
            "Mass cap \(Int(mission.massCap)) kg · \(mission.partCap) parts · \(mission.budget) cr · \(Int(mission.energyCap)) Wh.",
            mission.fixedFuelLoad.map { "Fuel load fixed at \(Int(($0 * 100).rounded()))% for this mission." },
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    static func completionNote(for controller: TaskGuideController) -> String {
        if controller.hadAlreadySatisfiedAutomaticTask {
            return "Rocket components verified. Some checks were already satisfied by the craft on the pad."
        }
        return "Rocket components verified."
    }
}
