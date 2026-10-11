import Testing
import SpacecraftCore
import FlightSim
import FlightCode
@testable import FlightRunner
import Curriculum

private func commands(_ src: String, _ lang: SourceLanguage, _ craft: CraftDesign, _ mission: Mission) throws -> ([CommandEvent], FlightResult) {
    let sim = FlightSimulation(craft: craft, mission: mission)
    let g = try ScriptGuidance(source: src, language: lang)
    g.attach(to: sim)
    let r = sim.runToEnd()
    return (g.commands, r)
}

/// specs/12: C translations must produce the same command stream as the Python reference.
struct CLessonTests {
    @Test(arguments: [0, 1])
    func cMatchesPython(_ lesson: Int) throws {
        let l = Lesson.all[lesson]
        let craft: CraftDesign = .rHop()
        let (py, pr) = try commands(l.referenceCode, .python, craft, l.mission)
        let (c, cr) = try commands(LessonCodeC.reference(lesson)!, .c, craft, l.mission)
        #expect(!py.isEmpty)
        #expect(py == c)
        #expect(pr.passed == cr.passed)
        #expect(pr.apogee == cr.apogee)
    }
}
