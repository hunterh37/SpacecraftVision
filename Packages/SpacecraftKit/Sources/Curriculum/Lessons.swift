import Foundation
import SpacecraftCore

public enum LessonStage: Int, CaseIterable, Sendable, Identifiable {
    case concept, pseudocode, implement, run, analyze
    public var id: Int { rawValue }
    /// Copy from specs/16 `stage.*`.
    public var title: String {
        switch self {
        case .concept: "Concept"; case .pseudocode: "Pseudocode"; case .implement: "Implement"; case .run: "Run"
        case .analyze: "Test and analyze"
        }
    }
}

public struct AnalysisQuestion: Sendable, Hashable {
    public var prompt: String
    public var plot: [String]
    public var options: [String]
    public var answer: Int
}

/// A hidden test checks the recorded command stream of a flight (specs/15 hidden tests).
public struct HiddenTestResult: Sendable, Hashable, Identifiable {
    public var id: String { name }
    public var name: String
    public var passed: Bool
}

public struct CommandRecord: Sendable, Hashable {
    public var t: Double, name: String, value: Double, altitude: Double, vz: Double
    public init(t: Double, name: String, value: Double, altitude: Double, vz: Double) {
        self.t = t; self.name = name; self.value = value; self.altitude = altitude; self.vz = vz
    }
}

public struct Lesson: Sendable, Identifiable, Hashable {
    public var id: Int
    public var title: String
    public var subtitle: String
    public var missionId: String
    public var narration: [String]
    /// Blocks in the correct order; the stage shuffles them.
    public var blocks: [String]
    public var distractors: [String]
    public var starterCode: String
    public var referenceCode: String
    public var question: AnalysisQuestion
    public var mission: Mission { Mission.named(missionId)! }

    public static func == (a: Lesson, b: Lesson) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }

    public func hiddenTests(_ cmds: [CommandRecord]) -> [HiddenTestResult] {
        switch id {
        case 0:
            let cut = cmds.first { $0.name == "set_throttle" && $0.value == 0 }
            let stages = cmds.filter { $0.name == "stage" }
            return [
                HiddenTestResult(name: "test_cutoff_in_window", passed: cut.map { $0.altitude >= 316 && $0.altitude <= 419 } ?? false),
                HiddenTestResult(name: "test_drogue_after_apogee", passed: stages.first.map { $0.vz < 0 } ?? false),
                HiddenTestResult(name: "test_main_below_250", passed: stages.count >= 2 && stages[1].altitude < 250),
                HiddenTestResult(name: "test_single_stage_per_phase", passed: stages.count == 2),
            ]
        case 1:
            let pitches = cmds.filter { $0.name == "set_pitch" }
            let yaws = cmds.filter { $0.name == "set_yaw" }
            return [
                HiddenTestResult(name: "test_rate_sign", passed: !pitches.isEmpty && pitches.contains { $0.value > 0 }),
                HiddenTestResult(name: "test_proportional", passed: Set(pitches.map(\.value)).count > 2),
                HiddenTestResult(name: "test_yaw_wrap", passed: !yaws.isEmpty && yaws.allSatisfy { abs($0.value) <= 0.5 + 1e-9 }),
                HiddenTestResult(name: "test_zero_error_zero_command", passed: pitches.contains { abs($0.value) < 1e-6 }),
            ]
        default: return []
        }
    }

    public static let all: [Lesson] = [
        Lesson(id: 0, title: "Loops and state", subtitle: "Cut the engine at the right height", missionId: "M1",
               narration: [
                "A rocket does the same small job many times a second. That repeated job is a loop.",
                "Your code runs fifty times each second. Each run is one tick.",
                "The rocket also needs to remember what it is doing: climbing, coasting or falling. That memory is the state.",
                "In the diorama, tap the steps to move the rocket from boost to coast to parachute.",
                "Cut the engine too late and the rocket flies too high. Too early and it falls short.",
               ],
               blocks: ["loop every tick", "if phase is boost and altitude >= CUTOFF_ALT: engine off, phase = coast",
                        "if phase is coast and falling: deploy drogue, phase = drogue",
                        "if phase is drogue and altitude < MAIN_ALT: deploy main, phase = main"],
               distractors: ["deploy main at launch"],
               starterCode: LessonCode.l0Starter, referenceCode: LessonCode.l0Reference,
               question: AnalysisQuestion(
                prompt: "Raise CUTOFF_ALT by 50 m and fly again. What happens to apogee and fuel used?",
                plot: ["altitude"],
                options: ["Apogee rises and more fuel is used", "Apogee rises and fuel used stays the same",
                          "Apogee falls and more fuel is used", "Nothing changes; apogee depends only on the parachute"],
                answer: 0)),
        Lesson(id: 1, title: "Feedback", subtitle: "Hold the pitch with a P controller", missionId: "M1W",
               narration: [
                "Wind pushes the rocket off its path. The rocket has to notice and push back.",
                "Measure the error: the pitch you want minus the pitch you have.",
                "Turn at a rate proportional to that error. Big error, fast turn. Small error, slow turn.",
                "The number that sets how hard you push back is the gain, KP.",
                "Balance the stick in the diorama. Watch what happens when your corrections are too small or too large.",
               ],
               blocks: ["error = target pitch - measured pitch", "pitch rate command = KP * error",
                        "same for yaw with target 0"],
               distractors: ["pitch rate command = KP / error"],
               starterCode: LessonCode.l1Starter, referenceCode: LessonCode.l1Reference,
               question: AnalysisQuestion(
                prompt: "Fly with KP = 0.2, then KP = 2.0. Which statement matches the pitch_error_deg plots?",
                plot: ["pitch_error_deg"],
                options: ["The small gain leaves a larger error that the wind keeps pushing",
                          "The small gain removes the error faster",
                          "Both gains give the same error because the wind is steady",
                          "The large gain makes the rocket climb higher"],
                answer: 0)),
        Lesson(id: 2, title: "PID", subtitle: "Steer through five gates", missionId: "M2",
               narration: [
                "A P controller can leave a steady error, and it can overshoot.",
                "The integral term adds up past error and removes the steady offset.",
                "The derivative term looks at how fast the error is changing and damps overshoot.",
                "Together they are PID: proportional, integral, derivative.",
                "Steer the cart to the line using all three dials and watch the response change.",
               ],
               blocks: ["error = bearing to next gate", "integral += error * dt",
                        "derivative = (error - previous error) / dt",
                        "yaw rate = KP * error + KI * integral + KD * derivative"],
               distractors: ["integral = 0 every tick"],
               starterCode: LessonCode.l2Starter, referenceCode: LessonCode.l2Reference,
               question: AnalysisQuestion(
                prompt: "Set KD to 0 and fly. What changes in the bearing_deg plot?",
                plot: ["bearing_deg"],
                options: ["Bearing overshoots more after each gate", "Bearing settles faster",
                          "Nothing changes", "The craft climbs higher"], answer: 0)),
    ]
}
