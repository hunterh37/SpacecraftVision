import Testing
import Foundation
import SpacecraftCore
import FlightSim
@testable import FlightRunner
import Curriculum

struct Scratch {
    @Test func scratchFly() throws {
        guard let path = ProcessInfo.processInfo.environment["SCRATCH_SRC"], let src = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        let mission = Mission.named(ProcessInfo.processInfo.environment["SCRATCH_MISSION"] ?? "M2")!
        let craftName = ProcessInfo.processInfo.environment["SCRATCH_CRAFT"] ?? "rGates"
        let craft: CraftDesign = craftName == "rHop" ? .rHop() : .rGates()
        let (r, _, sim) = try fly(src, craft, mission)
        print("RESULT", r.passed, r.gatesPassed, r.failure?.title ?? "pass", r.failure?.body ?? "", r.fuelUsed, r.minClearance ?? -1, r.score, sim.faultMessages.prefix(2))
        for s in sim.samples where Int((s.t * 50).rounded()) % 100 == 0 {
            print(String(format: "T %.0f pos %.0f %.0f %.0f v %.1f %.1f %.1f pitch %.1f yaw %.1f thr %.2f", s.t, s.position.x, s.position.y, s.position.z, s.velocity.x, s.velocity.y, s.velocity.z, s.pitch * 57.3, s.yaw * 57.3, s.throttle))
        }
    }
}
