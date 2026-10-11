import Foundation

/// Block palettes for the lessons that exist in the engine today. Scaffolds are cut from each lesson's reference
/// code, so composing the solution order with reference values reproduces the reference flight.
public enum LessonBlocks {
    private typealias N = BlockNode

    private static func cut(_ source: String, replacing body: String, constants: [String]) -> String {
        precondition(source.contains(body), "scaffold body not found in lesson source")
        var s = source.replacingOccurrences(of: body, with: "    {{BODY}}\n")
        for c in constants {
            // `NAME = 1.23` becomes `NAME = {{NAME}}`, keeping any trailing comment.
            let lines = s.components(separatedBy: "\n").map { line -> String in
                guard line.hasPrefix(c + " = ") else { return line }
                let rest = line.dropFirst(c.count + 3)
                let comment = rest.range(of: "#").map { " " + rest[$0.lowerBound...] } ?? ""
                return "\(c) = {{\(c)}}" + comment
            }
            s = lines.joined(separator: "\n")
        }
        return s
    }

    public static func program(forLesson id: Int) -> BlockProgram? {
        switch id {
        case 0: return lesson0
        case 1: return lesson1
        case 2: return lesson2
        default: return nil
        }
    }

    // MARK: Lesson 0, loops and state

    static let lesson0: BlockProgram = {
        let body = """
            if state["phase"] == "boost":
                if alt >= CUTOFF_ALT:
                    craft.set_throttle(0.0)
                    state["phase"] = "coast"
            elif state["phase"] == "coast":
                if vz < 0.0:
                    craft.stage()
                    state["phase"] = "drogue"
            elif state["phase"] == "drogue":
                if alt < MAIN_ALT:
                    craft.stage()
                    state["phase"] = "main"

        """
        let ref = LessonCode.l0Reference
        let scaffold = cut(ref, replacing: body, constants: ["CUTOFF_ALT", "MAIN_ALT"])
        return BlockProgram(
            scaffold: scaffold,
            specs: [
                BlockSpec(id: "l0.boost", name: "Cut the engine", summary: "While boosting, stop the engine at the cutoff altitude and start coasting.", category: .control,
                          lines: ["if state[\"phase\"] == \"boost\" and alt >= CUTOFF_ALT:", "    craft.set_throttle(0.0)", "    state[\"phase\"] = \"coast\""],
                          nodes: [N(.control, [.text("if"), .variable("phase"), .text("is boost and"), .variable("alt"), .text(">="), .input("CUTOFF_ALT"), .text("m")], lines: 0...2, kids: [
                            N(.motion, [.text("set throttle to 0")], lines: 1...1),
                            N(.variables, [.text("set"), .variable("phase"), .text("to coast")], lines: 2...2)])]),
                BlockSpec(id: "l0.coast", name: "Drogue at apogee", summary: "While coasting, open the drogue chute once the rocket starts to fall.", category: .control,
                          lines: ["if state[\"phase\"] == \"coast\" and vz < 0.0:", "    craft.stage()", "    state[\"phase\"] = \"drogue\""],
                          nodes: [N(.control, [.text("if"), .variable("phase"), .text("is coast and"), .variable("vz"), .text("< 0 (falling)")], lines: 0...2, kids: [
                            N(.motion, [.text("deploy drogue")], lines: 1...1),
                            N(.variables, [.text("set"), .variable("phase"), .text("to drogue")], lines: 2...2)])]),
                BlockSpec(id: "l0.main", name: "Main chute low", summary: "While under the drogue, open the main chute below the main altitude.", category: .control,
                          lines: ["if state[\"phase\"] == \"drogue\" and alt < MAIN_ALT:", "    craft.stage()", "    state[\"phase\"] = \"main\""],
                          nodes: [N(.control, [.text("if"), .variable("phase"), .text("is drogue and"), .variable("alt"), .text("<"), .input("MAIN_ALT"), .text("m")], lines: 0...2, kids: [
                            N(.motion, [.text("deploy main chute")], lines: 1...1),
                            N(.variables, [.text("set"), .variable("phase"), .text("to main")], lines: 2...2)])]),
                BlockSpec(id: "l0.early", name: "Deploy at launch", summary: "Fires a parachute every tick, no matter what.", category: .motion, distractor: true,
                          lines: ["craft.stage()"], nodes: [N(.motion, [.text("deploy parachute now")], lines: 0...0)]),
            ],
            knobs: [BlockKnob("CUTOFF_ALT", "Cutoff altitude", start: 150, reference: 360, range: 50...600, step: 10, unit: "m"),
                    BlockKnob("MAIN_ALT", "Main chute altitude", start: 250, reference: 250, range: 100...400, step: 10, unit: "m")],
            solution: ["l0.boost", "l0.coast", "l0.main"])
    }()

    // MARK: Lesson 1, feedback

    static let lesson1: BlockProgram = {
        let body = """
            err = pitch_target(alt) - pitch
            craft.set_pitch(KP * err)
            craft.set_yaw(KP * wrap(0.0 - yaw))

        """
        let scaffold = cut(LessonCode.l1Reference, replacing: body, constants: ["KP"])
        return BlockProgram(
            scaffold: scaffold,
            specs: [
                BlockSpec(id: "l1.error", name: "Measure the error", summary: "How far is the measured pitch from the pitch we want?", category: .operators,
                          lines: ["err = pitch_target(alt) - pitch"],
                          nodes: [N(.operators, [.text("set"), .variable("err"), .text("to"), .reporter("target pitch"), .text("-"), .variable("pitch")], lines: 0...0)]),
                BlockSpec(id: "l1.pitch", name: "Push pitch back", summary: "Command a pitch rate proportional to the error.", category: .motion,
                          lines: ["craft.set_pitch(KP * err)"],
                          nodes: [N(.motion, [.text("pitch rate ="), .input("KP"), .text("×"), .variable("err")], lines: 0...0)]),
                BlockSpec(id: "l1.yaw", name: "Push yaw back", summary: "Same idea for yaw, aiming for zero.", category: .motion,
                          lines: ["craft.set_yaw(KP * wrap(0.0 - yaw))"],
                          nodes: [N(.motion, [.text("yaw rate ="), .input("KP"), .text("×"), .reporter("0 - yaw")], lines: 0...0)]),
                BlockSpec(id: "l1.divide", name: "Divide by error", summary: "A rate that grows as the error shrinks.", category: .motion, distractor: true,
                          lines: ["craft.set_pitch(KP / err)"],
                          nodes: [N(.motion, [.text("pitch rate ="), .input("KP"), .text("÷"), .variable("err")], lines: 0...0)]),
            ],
            knobs: [BlockKnob("KP", "Gain KP", start: 0.0, reference: 2.0, range: 0...4, step: 0.1, unit: "1/s")],
            solution: ["l1.error", "l1.pitch", "l1.yaw"])
    }()

    // MARK: Lesson 2, PID

    static let lesson2: BlockProgram = {
        let body = """
            pid["integral"] = math.clamp(pid["integral"] + err * dt, -I_LIMIT, I_LIMIT)
            if pid["first"]:
                deriv = 0.0
                pid["first"] = False
            else:
                deriv = wrap(err - pid["prev"]) / dt
            pid["prev"] = err
            return KP * err + KI * pid["integral"] + KD * deriv

        """
        let scaffold = cut(LessonCode.l2Reference, replacing: body, constants: ["KP", "KI", "KD"])
        return BlockProgram(
            scaffold: scaffold,
            specs: [
                BlockSpec(id: "l2.integral", name: "Add up the error", summary: "The integral remembers past error and removes steady offset.", category: .operators,
                          lines: ["pid[\"integral\"] = math.clamp(pid[\"integral\"] + err * dt, -I_LIMIT, I_LIMIT)"],
                          nodes: [N(.operators, [.text("change"), .variable("integral"), .text("by"), .variable("err"), .text("×"), .variable("dt"), .text("(clamped)")], lines: 0...0)]),
                BlockSpec(id: "l2.derivative", name: "How fast it changes", summary: "The derivative looks at how quickly the error is changing and damps overshoot.", category: .control,
                          lines: ["if pid[\"first\"]:", "    deriv = 0.0", "    pid[\"first\"] = False", "else:", "    deriv = wrap(err - pid[\"prev\"]) / dt", "pid[\"prev\"] = err"],
                          nodes: [
                            N(.control, [.text("if this is the first tick")], lines: 0...2, kids: [N(.variables, [.text("set"), .variable("deriv"), .text("to 0")], lines: 1...2)]),
                            N(.control, [.text("else")], lines: 3...4, kids: [N(.operators, [.text("set"), .variable("deriv"), .text("to"), .reporter("change in error"), .text("÷"), .variable("dt")], lines: 4...4)]),
                            N(.variables, [.text("remember"), .variable("err"), .text("for next tick")], lines: 5...5)]),
                BlockSpec(id: "l2.output", name: "Yaw command", summary: "Add the three terms together.", category: .motion,
                          lines: ["return KP * err + KI * pid[\"integral\"] + KD * deriv"],
                          nodes: [N(.motion, [.text("yaw rate ="), .input("KP"), .text("× error +"), .input("KI"), .text("× integral +"), .input("KD"), .text("× derivative")], lines: 0...0)]),
                BlockSpec(id: "l2.reset", name: "Reset the integral", summary: "Throws the memory away every tick.", category: .variables, distractor: true,
                          lines: ["pid[\"integral\"] = 0.0"],
                          nodes: [N(.variables, [.text("set"), .variable("integral"), .text("to 0")], lines: 0...0)]),
            ],
            knobs: [BlockKnob("KP", "Gain KP", start: 0.0, reference: 1.2, range: 0...3, step: 0.05, unit: "1/s"),
                    BlockKnob("KI", "Gain KI", start: 0.0, reference: 0.05, range: 0...0.5, step: 0.01),
                    BlockKnob("KD", "Gain KD", start: 0.0, reference: 0.4, range: 0...1.5, step: 0.05)],
            solution: ["l2.integral", "l2.derivative", "l2.output"])
    }()
}

public extension Lesson {
    /// The lesson's blocks, or nil for lessons the engine cannot run yet.
    var blockProgram: BlockProgram? { LessonBlocks.program(forLesson: id) }
}
