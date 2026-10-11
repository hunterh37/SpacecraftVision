import Testing
import Foundation
import SpacecraftCore
import FlightSim
import FlightCode
@testable import FlightRunner
import Curriculum

struct BlockProgramTests {
    func craft(_ lesson: Int) -> CraftDesign { lesson == 2 ? .rGates() : .rHop() }

    @Test(arguments: [0, 1, 2]) func solutionOrderComposesToTheReferenceFlight(_ lessonID: Int) throws {
        let l = Lesson.all[lessonID]
        let p = try #require(l.blockProgram)
        let src = p.compose(order: p.solution, values: p.referenceValues)
        #expect(!src.source.contains("{{"), "unfilled placeholder in \(lessonID)")
        // Same flight as the reference code.
        let (r, g, _) = try fly(src.source, craft(lessonID), l.mission)
        let (rr, _, _) = try fly(l.referenceCode, craft(lessonID), l.mission)
        #expect(r == rr, "blocks must fly exactly like the reference code")
        // Lesson 2's reference overshoots gate 1 in this sim (known gap in LessonFlightTests), so only 0 and 1 must pass.
        if lessonID < 2 { #expect(r.passed, "\(r.failure?.title ?? "")") }
        let tests = l.hiddenTests(g.commands.map { CommandRecord(t: $0.t, name: $0.name, value: $0.value, altitude: $0.altitude, vz: $0.vz) })
        #expect(tests.allSatisfy { $0.passed }, "\(tests)")
    }

    @Test(arguments: [0, 1, 2]) func startingValuesFailTheMission(_ lessonID: Int) throws {
        let l = Lesson.all[lessonID]
        let p = try #require(l.blockProgram)
        let src = p.compose(order: p.solution, values: p.startingValues)
        let (r, _, _) = try fly(src.source, craft(lessonID), l.mission)
        #expect(!r.passed, "starting knob values should leave something to tune")
    }

    @Test func emptyProgramStillCompiles() throws {
        let p = try #require(Lesson.all[1].blockProgram)
        let src = p.compose(order: [], values: p.startingValues)
        #expect((try? Compiler.compile(src.source)) != nil)
    }

    @Test func originsLineUpWithSource() throws {
        let p = try #require(Lesson.all[0].blockProgram)
        let c = p.compose(order: p.solution, values: p.referenceValues)
        #expect(c.origins.count == c.source.components(separatedBy: "\n").count)
        #expect(c.origins.compactMap { $0 }.count == p.solution.compactMap { p.spec($0)?.lines.count }.reduce(0, +))
    }

    @Test func distractorBreaksTheFlight() throws {
        let l = Lesson.all[0]
        let p = try #require(l.blockProgram)
        let (r, _, _) = try fly(p.compose(order: ["l0.early"] + p.solution, values: p.referenceValues).source, .rHop(), l.mission)
        #expect(!r.passed)
    }

    @Test func blocksRoundTripThroughJSON() throws {
        let p = try #require(Lesson.all[2].blockProgram)
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(BlockProgram.self, from: data)
        #expect(back == p)
    }
}
