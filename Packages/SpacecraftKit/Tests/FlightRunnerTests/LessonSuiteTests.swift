import Testing
import Foundation
import SpacecraftCore
import FlightSim
@testable import FlightRunner
import Curriculum

/// Every lesson from 2 up: reference passes its mission and its hidden tests; starter fails the mission.
struct LessonSuiteTests {
    static func craft(_ l: Lesson) -> CraftDesign {
        switch l.missionId {
        case "M2", "M3": .rGates()
        case "M2B": .rWalls()
        case "M6": .rDebris()
        case "M4", "M5": .aField()
        default: l.mission.isAircraft ? .aField() : .rHop()
        }
    }

    static let ids = Lesson.all.map(\.id).filter { $0 >= 2 && $0 <= 9 }

    @Test(arguments: ids) func referencePassesWithHiddenTests(_ id: Int) throws {
        let l = Lesson.all.first { $0.id == id }!
        let r = FlightPreview.run(source: l.referenceCode, craft: Self.craft(l), mission: l.mission)
        #expect(r.compileError == nil)
        let why = r.result.failure?.body ?? ""
        #expect(r.result.passed, "L\(id): \(why)")
        let tests = l.unitTests(source: l.referenceCode)
        let failing = tests.filter { !$0.passed }.map(\.name)
        #expect(failing.isEmpty, "L\(id): \(failing)")
    }

    @Test(arguments: ids) func starterFails(_ id: Int) throws {
        let l = Lesson.all.first { $0.id == id }!
        let r = FlightPreview.run(source: l.starterCode, craft: Self.craft(l), mission: l.mission)
        #expect(r.compileError == nil)
        #expect(!r.result.passed)
    }
}
