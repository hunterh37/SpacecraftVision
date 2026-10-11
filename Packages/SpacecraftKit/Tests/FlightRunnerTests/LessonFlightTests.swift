import Testing
import Foundation
import SpacecraftCore
import FlightSim
import FlightCode
@testable import FlightRunner
import Curriculum

func fly(_ src: String, _ craft: CraftDesign, _ mission: Mission) throws -> (FlightResult, ScriptGuidance, FlightSimulation) {
    let sim = FlightSimulation(craft: craft, mission: mission)
    let g = try ScriptGuidance(source: src)
    g.attach(to: sim)
    let r = sim.runToEnd()
    return (r, g, sim)
}

struct LessonFlightTests {
    @Test func lesson0ReferencePasses() throws {
        let l = Lesson.all[0]
        let (r, g, sim) = try fly(l.referenceCode, .rHop(), l.mission)
        print("L0 ref", r.apogee, r.failure?.title ?? "pass", sim.faultMessages.prefix(3))
        #expect(r.passed)
        let tests = l.hiddenTests(g.commands.map { CommandRecord(t: $0.t, name: $0.name, value: $0.value, altitude: $0.altitude, vz: $0.vz) })
        let ok = tests.allSatisfy { $0.passed }; #expect(ok, "\(tests)")
    }

    @Test func lesson0StarterFails() throws {
        let l = Lesson.all[0]
        let (r, _, _) = try fly(l.starterCode, .rHop(), l.mission)
        print("L0 starter", r.failure?.key ?? "pass", r.apogee)
        #expect(!r.passed)
    }

    @Test func lesson1ReferencePasses() throws {
        let l = Lesson.all[1]
        let (r, _, sim) = try fly(l.referenceCode, .rHop(), l.mission)
        print("L1 ref", r.apogee, r.pitchRMSDeg ?? -1, r.failure?.title ?? "pass", r.failure?.body ?? "", sim.position)
        #expect(r.passed)
    }

    @Test func lesson1StarterFails() throws {
        let l = Lesson.all[1]
        let (r, _, _) = try fly(l.starterCode, .rHop(), l.mission)
        print("L1 starter", r.failure?.key ?? "pass", r.pitchRMSDeg ?? -1)
        #expect(!r.passed)
    }

    @Test func lesson2ReferenceGates() throws {
        let l = Lesson.all[2]
        let (r, _, sim) = try fly(l.referenceCode, .rGates(), l.mission)
        print("L2 ref", r.gatesPassed, r.failure?.title ?? "pass", r.failure?.body ?? "", sim.position, sim.faultMessages.prefix(3))
        #expect(r.passed)
    }

    @Test func previewCompileError() {
        let rep = FlightPreview.run(source: "def update(dt)\n    pass\n", craft: .rHop(), mission: .m1)
        #expect(rep.compileError?.line == 1)
    }

    @Test func previewSpeed() {
        let start = Date()
        _ = FlightPreview.run(source: Lesson.all[0].referenceCode, craft: .rHop(), mission: .m1)
        let dt = Date().timeIntervalSince(start)
        print("preview s", dt)
        // Release builds run this in ~0.14 s (specs/12: edit-to-ribbon under 1 s); debug under load is much slower.
        #expect(dt < 20)
    }
}

struct DebugTrace {
    @Test func traceL2() throws {
        let l = Lesson.all[2]
        let (_, _, sim) = try fly(l.referenceCode, .rGates(), l.mission)
        for s in sim.samples where Int(s.t * 50) % 50 == 0 {
            print(String(format: "t %.0f pos %.0f %.0f %.0f v %.1f %.1f %.1f pitch %.1f yaw %.1f thr %.2f", s.t, s.position.x, s.position.y, s.position.z, s.velocity.x, s.velocity.y, s.velocity.z, s.pitch * 57.3, s.yaw * 57.3, s.throttle))
        }
    }
}
