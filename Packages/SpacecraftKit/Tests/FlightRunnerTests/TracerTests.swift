import Testing
import Foundation
import SpacecraftCore
import FlightSim
import FlightCode
@testable import FlightRunner
import Curriculum

struct TracerTests {
    let l1 = Lesson.all[1]

    @Test func tracesOneTickWithLinesVariablesAndCalls() throws {
        let t = FlightTracer.trace(source: l1.referenceCode, craft: .rHop(), mission: l1.mission, atTime: 3.0)
        #expect(t.compileError == nil)
        #expect(t.steps.count > 10)
        #expect(t.time >= 3.0 && t.time < 3.1)
        #expect(t.bytecodeOps > 50)
        #expect(t.instructions > 0 && t.instructions < t.instructionBudget)
        let lines = l1.referenceCode.components(separatedBy: "\n").count
        #expect(t.steps.allSatisfy { $0.line >= 1 && $0.line <= lines })
        // The controller runs: pitch is read, error computed, a rate is commanded.
        let calls = t.steps.flatMap(\.calls)
        #expect(calls.contains { $0.hasPrefix("craft.attitude()") })
        #expect(calls.contains { $0.hasPrefix("craft.set_pitch(") })
        // The local `err` shows up once it has been assigned, with a numeric value.
        let err = t.steps.compactMap { $0.variables.first { $0.name == "err" } }.last
        #expect(err?.number != nil)
        // Module constants are visible too.
        #expect(t.steps.last?.variables.contains { $0.name == "KP" && $0.number == 2.0 } == true)
    }

    @Test func traceIsDeterministic() throws {
        let a = FlightTracer.trace(source: l1.referenceCode, craft: .rHop(), mission: l1.mission, atTime: 3.0)
        let b = FlightTracer.trace(source: l1.referenceCode, craft: .rHop(), mission: l1.mission, atTime: 3.0)
        #expect(a == b)
    }

    @Test func compileErrorIsReported() {
        let t = FlightTracer.trace(source: "def update(dt)\n    pass\n", craft: .rHop(), mission: l1.mission, atTime: 1)
        #expect(t.compileError != nil)
        #expect(t.steps.isEmpty)
    }

    @Test func faultIsReportedWithLine() {
        let src = "import craft\ndef update(dt):\n    x = 1\n    y = x / 0\n"
        let t = FlightTracer.trace(source: src, craft: .rHop(), mission: l1.mission, atTime: 0.1)
        #expect(t.steps.contains { $0.line == 4 })
        #expect(t.faultLine == 4)
    }

    @Test func loopsTurnOverOnTheSameLine() {
        let src = "import craft\ndef update(dt):\n    i = 0\n    while i < 3:\n        i += 1\n"
        let t = FlightTracer.trace(source: src, craft: .rHop(), mission: l1.mission, atTime: 1)
        let counts = t.steps.filter { $0.line == 5 }.count
        #expect(counts == 3)
    }
}
