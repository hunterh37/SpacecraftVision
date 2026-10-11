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

    /// Hidden unit tests run on the player's code (lessons 2 to 9); empty for lessons graded on the command stream.
    public func unitTests(source: String) -> [HiddenTestResult] { HiddenTests.run(lesson: id, source: source) }

    public func hiddenTests(_ cmds: [CommandRecord]) -> [HiddenTestResult] {
        switch id {
        case 0:
            let cut = cmds.first { $0.name == "set_throttle" && $0.value == 0 }
            let stages = cmds.filter { $0.name == "stage" }
            return [
                HiddenTestResult(name: "test_cutoff_in_window", passed: cut.map { $0.altitude >= 316 && $0.altitude <= 419 } ?? false),
                HiddenTestResult(name: "test_drogue_after_apogee", passed: stages.first.map { $0.vz < 0 } ?? false),
                HiddenTestResult(name: "test_main_below_250", passed: stages.count >= 2 && stages[1].altitude < 253),
                HiddenTestResult(name: "test_single_stage_per_phase", passed: stages.count == 2),
            ]
        case 1:
            let pitches = cmds.filter { $0.name == "set_pitch" }
            let yaws = cmds.filter { $0.name == "set_yaw" }
            return [
                HiddenTestResult(name: "test_rate_sign", passed: !pitches.isEmpty && pitches.contains { $0.value > 0 }),
                HiddenTestResult(name: "test_proportional", passed: Set(pitches.map(\.value)).count > 2),
                HiddenTestResult(name: "test_yaw_wrap", passed: !yaws.isEmpty && yaws.allSatisfy { abs($0.value) <= 0.5 + 1e-9 }),
                HiddenTestResult(name: "test_zero_error_zero_command", passed: pitches.contains { abs($0.value) < 0.005 }),
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
        Lesson(id: 3, title: "Reactive avoidance", subtitle: "Bug 0 around walls", missionId: "M2B",
               narration: [
                "The rover knows where home is. It does not have a map.",
                "Rule one: drive toward the goal.",
                "Rule two: if something is closer than a safe distance ahead, turn toward the more open side.",
                "Rule three: as soon as the way to the goal is clear, head for the goal again.",
                "This is Bug 0. Steer three rovers home by hand, then watch the rule do it.",
               ],
               blocks: ["loop every tick", "if obstacle closer than SAFE_DIST ahead: turn toward the open side",
                        "else: head to goal"],
               distractors: ["if obstacle closer than SAFE_DIST: stop the engine"],
               starterCode: LessonCode.l3Starter, referenceCode: LessonCode.l3Reference,
               question: AnalysisQuestion(
                prompt: "Fly with SAFE_DIST doubled. Which constant sets the minimum clearance, and what happens to fuel?",
                plot: ["front_range"],
                options: ["SAFE_DIST; fuel used rises because the craft turns earlier and flies a longer path",
                          "SAFE_DIST; fuel used falls because the craft slows down",
                          "TURN_DEG; fuel used does not change",
                          "CRUISE_ALT; fuel used rises because the craft climbs"], answer: 0)),
        Lesson(id: 4, title: "Bug 2", subtitle: "Follow the line, follow the wall, leave", missionId: "M4",
               narration: [
                "Bug 0 can circle forever around some shapes. Bug 2 adds memory.",
                "Draw a line from start to goal. This is the M-line.",
                "Follow the M-line. When you hit an obstacle, remember how far the goal is.",
                "Follow the obstacle's edge until you meet the M-line again closer to the goal.",
                "Then leave the edge and continue on the line. Guide the rover around the wall shapes.",
               ],
               blocks: ["go: follow the M-line toward the goal",
                        "if obstacle ahead closer than HIT_DIST: remember goal distance, switch to follow",
                        "follow: keep the obstacle on the right at FOLLOW_DIST",
                        "leave when back on the M-line and closer to the goal than at the hit point"],
               distractors: ["leave as soon as the obstacle is out of sight"],
               starterCode: LessonCode.l4Starter, referenceCode: LessonCode.l4Reference,
               question: AnalysisQuestion(
                prompt: "Look at mline_offset. What does each excursion away from zero show?",
                plot: ["mline_offset"],
                options: ["A wall being followed until the craft rejoins the M-line closer to the goal",
                          "Wind pushing the craft off course", "The craft climbing over a wall",
                          "A sensor dropout"], answer: 0)),
        Lesson(id: 5, title: "Potential fields", subtitle: "Pulled by the goal, pushed by obstacles", missionId: "M4",
               narration: [
                "Imagine the goal pulls on the craft like a spring.",
                "Every obstacle pushes back, harder the closer you get.",
                "Add the pull and the pushes. Steer along the sum.",
                "Some shapes create a spot where pull and push cancel. This is a local minimum.",
                "Roll the marble down the slope and find where it gets stuck.",
               ],
               blocks: ["force = attraction toward goal",
                        "for each lidar hit closer than R0: add repulsion away from the hit",
                        "steer toward the force direction",
                        "if no progress for STUCK_TIME: push sideways to escape"],
               distractors: ["for each lidar hit: add attraction toward the hit"],
               starterCode: LessonCode.l5Starter, referenceCode: LessonCode.l5Reference,
               question: AnalysisQuestion(
                prompt: "Halve K_REP and fly. What happens to the minimum clearance?",
                plot: ["force_angle_deg"],
                options: ["It shrinks: obstacles push later and weaker", "It grows", "It does not change",
                          "The craft stops at the first wall"], answer: 0)),
        Lesson(id: 7, title: "Velocity obstacles", subtitle: "Dodge moving debris", missionId: "M6",
               narration: [
                "Debris moves. Avoiding where it is now is not enough.",
                "For each velocity you could choose, predict where you and the debris will be.",
                "If you would come too close within the time horizon, that velocity is inside the collision cone.",
                "Choose the allowed velocity closest to the one you want.",
                "Drag the velocity arrow in the diorama out of every cone.",
               ],
               blocks: ["for each candidate horizontal velocity on a grid",
                        "for each radar track: find the closest approach within HORIZON s",
                        "reject the candidate if any closest approach is under radius + MARGIN",
                        "pick the allowed candidate nearest the preferred velocity", "tilt to reach it"],
               distractors: ["pick the candidate pointing straight at the debris"],
               starterCode: LessonCode.l7Starter, referenceCode: LessonCode.l7Reference,
               question: AnalysisQuestion(
                prompt: "Halve HORIZON and fly. What happens in the tracks plot and to clearance?",
                plot: ["tracks"],
                options: ["Debris is dodged later, so minimum clearance shrinks", "Clearance grows",
                          "Nothing changes", "The craft stops climbing"], answer: 0)),
        Lesson(id: 9, title: "Sampling planning", subtitle: "Grow a tree through the debris", missionId: "M6",
               narration: [
                "Some spaces are too large or move too fast for a grid.",
                "Pick random points. Connect each to the nearest branch of a tree, one short step at a time.",
                "Throw away any step that would hit an obstacle.",
                "When a branch reaches the goal, cut corners to straighten the path.",
                "Grow the tree in the diorama and watch it find a way through.",
               ],
               blocks: ["sample a random point (sometimes the goal)", "find the nearest tree node",
                        "step toward the sample; keep the step if it is predicted clear",
                        "trace the best branch back and shortcut it", "steer along the path"],
               distractors: ["keep every step even if it hits an obstacle"],
               starterCode: LessonCode.l9Starter, referenceCode: LessonCode.l9Reference,
               question: AnalysisQuestion(
                prompt: "Set GOAL_BIAS to 0 and fly. What changes?",
                plot: ["tracks"],
                options: ["The tree spreads sideways and paths reach less far up", "Paths get straighter",
                          "Fuel use halves", "Nothing changes"], answer: 0)),
    ]
}
