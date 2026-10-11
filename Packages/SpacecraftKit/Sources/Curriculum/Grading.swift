import Foundation
import SpacecraftCore

/// Outcome of one run, as grading needs it (specs/06 grading).
public struct RunSummary: Sendable, Hashable {
    public var passed: Bool
    public var fuelUsed: Double
    public var energyUsedWh: Double
    public var minClearance: Double?
    public var apogee: Double
    /// Flight score computed by the simulator (used whole for the capstone).
    public var flightScore: Int
    public init(passed: Bool, fuelUsed: Double, energyUsedWh: Double, minClearance: Double?, apogee: Double, flightScore: Int) {
        self.passed = passed; self.fuelUsed = fuelUsed; self.energyUsedWh = energyUsedWh; self.minClearance = minClearance
        self.apogee = apogee; self.flightScore = flightScore
    }
}

public struct Grade: Sendable, Hashable {
    public var score: Int
    public var stars: Int
    public var tests: [HiddenTestResult]
}

/// Mission pass required; hidden tests 40%, fuel (energy for electric craft) vs par 20%, clearance vs par
/// 20% (apogee error on hop missions), analysis answer 20%. Stars at 60, 80, 95. Lesson 10: score only.
public enum Grading {
    public static func grade(_ lesson: Lesson, run: RunSummary, tests: [HiddenTestResult], answerCorrect: Bool) -> Grade? {
        guard run.passed else { return nil }
        let m = lesson.mission
        var score: Double
        if case .capstone = m.goal {
            score = Double(run.flightScore)
        } else {
            let testScore = tests.isEmpty ? 40.0 : 40.0 * Double(tests.filter(\.passed).count) / Double(tests.count)
            let used = m.isAircraft ? run.energyUsedWh : run.fuelUsed
            let fuel = 20 * min(1, m.parFuel / max(used, 1))
            let second: Double
            switch m.goal {
            case .hop: second = 20 * max(0, 1 - abs(run.apogee - 1100) / 100)
            default: second = 20 * min(1, max(0, run.minClearance ?? 0) / (m.parClearance ?? 6))
            }
            score = testScore + fuel + second + (answerCorrect ? 20 : 0)
        }
        let s = Int(score.rounded())
        return Grade(score: s, stars: s >= 95 ? 3 : s >= 80 ? 2 : s >= 60 ? 1 : 0, tests: tests)
    }
}
