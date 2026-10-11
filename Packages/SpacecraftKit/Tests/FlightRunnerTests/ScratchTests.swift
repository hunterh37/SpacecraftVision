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
        let craft: CraftDesign = ["rHop": .rHop(), "rWalls": .rWalls(), "rDebris": .rDebris(), "aField": .aField()][craftName] ?? .rGates()
        let (r, _, sim) = try fly(src, craft, mission)
        print("RESULT", r.passed, r.gatesPassed, r.failure?.title ?? "pass", r.failure?.body ?? "", "fuel", r.fuelUsed, "Wh", r.energyUsedWh, "clr", r.minClearance ?? -1, "score", r.score, sim.faultMessages.prefix(2))
        let every = Int(ProcessInfo.processInfo.environment["SCRATCH_EVERY"] ?? "100") ?? 100
        for s in sim.samples where Int((s.t * 50).rounded()) % every == 0 {
            print(String(format: "T %.0f pos %.0f %.0f %.0f v %.1f %.1f %.1f pitch %.1f yaw %.1f roll %.1f thr %.2f clr %.1f", s.t, s.position.x, s.position.y, s.position.z, s.velocity.x, s.velocity.y, s.velocity.z, s.pitch * 57.3, s.yaw * 57.3, s.roll * 57.3, s.throttle, s.clearance ?? -1))
        }
        for e in sim.events.prefix(30) { print("EV", String(format: "%.1f", e.t), e.text) }
        for (k, vs) in sim.userSeries.sorted(by: { $0.key < $1.key }) {
            for (i, x) in vs.enumerated() where i % every == 0 { print("SER", k, String(format: "%.1f %.2f", x.t, x.v)) }
        }
    }
    @Test func scratchCourses() {
        print("COURSES", Course.all.map(\.id))
    }
}
struct Scratch2 {
    @Test func scratchChallenge() {
        for c in AlgorithmChallenge.all {
            let m = Mission.named(c.id)!
            var craft = CraftDesign.rHop(); craft.payloadMass = m.payloadMass
            print("CH", c.id, "starter")
            let sim = FlightSimulation(craft: craft, mission: m)
            let g = try! ScriptGuidance(source: c.starterCode)
            g.attach(to: sim)
            var n = 0
            while !sim.finished && n < 200_000 { sim.step(); n += 1; if n % 20000 == 0 { print("CH t", sim.time, sim.position, sim.velocity) } }
            print("CH done", sim.result?.failure?.title ?? "pass")
        }
    }
}
struct Scratch3 {
    @Test func scratchPreview() {
        for c in AlgorithmChallenge.all {
            let m = Mission.named(c.id)!
            var craft = CraftDesign.rHop(); craft.payloadMass = m.payloadMass
            print("PV", c.id); fflush(stdout)
            let r = FlightPreview.run(source: c.starterCode, craft: craft, mission: m)
            print("PV starter", r.result.passed); fflush(stdout)
            let r2 = FlightPreview.run(source: c.referenceCode, craft: craft, mission: m)
            print("PV ref", r2.result.passed, r2.result.failure?.title ?? ""); fflush(stdout)
        }
    }
}
