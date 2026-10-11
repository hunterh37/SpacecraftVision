import Foundation
import SpacecraftCore
import FlightSim
import FlightCode

/// One variable shown beside a trace step.
public struct TraceVar: Sendable, Hashable, Codable {
    public var name: String
    /// Display text, e.g. `0.31`, `'coast'`, `{'phase': 'boost'}`.
    public var text: String
    /// Set for ints, floats and bools so the UI can format angles or draw bars.
    public var number: Double?
}

/// A line about to run, the variables visible then, and the craft calls it made.
public struct TraceStep: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var function: String
    public var line: Int
    public var variables: [TraceVar]
    /// Craft API calls executed by this line, in order: `craft.altitude() -> 312.4`.
    public var calls: [String]
}

/// Everything the Trace tab needs about one guidance tick.
public struct TraceReport: Sendable, Hashable, Codable {
    public var time: Double
    public var steps: [TraceStep]
    public var instructions: Int
    public var instructionBudget: Int
    public var bytecodeOps: Int
    public var compileError: String?
    public var fault: String?
    public var faultLine: Int?
    public static func empty(error: String? = nil) -> TraceReport {
        TraceReport(time: 0, steps: [], instructions: 0, instructionBudget: VM.tickBudget, bytecodeOps: 0, compileError: error, fault: nil, faultLine: nil)
    }
}

final class TraceRecorder {
    var steps: [TraceStep] = []
    var instructions = 0
    private static let maxSteps = 600

    private static func display(_ v: Value) -> TraceVar.Brief {
        let text = v.repr
        let short = text.count > 80 ? String(text.prefix(77)) + "..." : text
        switch v {
        case let .int(i): return .init(text: short, number: Double(i))
        case let .float(d): return .init(text: short, number: d)
        case let .bool(b): return .init(text: short, number: b ? 1 : 0)
        case let .str(s): return .init(text: "'\(s)'", number: nil)
        default: return .init(text: short, number: nil)
        }
    }

    func stop(_ s: TraceStop) {
        guard steps.count < Self.maxSteps else { return }
        steps.append(TraceStep(id: steps.count, function: s.function, line: s.line,
                               variables: s.variables.map { n, v in let b = Self.display(v); return TraceVar(name: n, text: b.text, number: b.number) },
                               calls: []))
    }

    func call(_ name: String, _ args: [Value], _ result: Value) {
        guard !steps.isEmpty else { return }
        let a = args.map { $0.repr }.joined(separator: ", ")
        let r = result.repr
        steps[steps.count - 1].calls.append("craft.\(name)(\(a))" + (r == "None" ? "" : " -> \(r)"))
    }
}

extension TraceVar {
    struct Brief { var text: String; var number: Double? }
}

public enum FlightTracer {
    /// Fly the mission with `source` until `time`, then record the next guidance tick step by step.
    /// The flight up to that point is identical to a normal run: same seed, same step.
    public static func trace(source: String, craft: CraftDesign, mission: Mission, seed: UInt64 = 1, atTime time: Double) -> TraceReport {
        let sim = FlightSimulation(craft: craft, mission: mission, seed: seed)
        let g: ScriptGuidance
        do { g = try ScriptGuidance(source: source) }
        catch let e as CompileError { return .empty(error: "Line \(e.line): \(e.message)") }
        catch { return .empty(error: "\(error)") }
        g.attach(to: sim)
        while !sim.finished && sim.time < time { sim.step() }
        guard !sim.finished else { return .empty() }
        g.traceNextUpdate = true
        var spins = 0
        while !sim.finished && g.lastTrace == nil && spins < 4000 { sim.step(); spins += 1 }
        guard let rec = g.lastTrace else { return .empty() }
        let fault = sim.faultMessages.last
        return TraceReport(time: sim.time, steps: rec.steps, instructions: rec.instructions, instructionBudget: VM.tickBudget,
                           bytecodeOps: g.program.opCount, compileError: nil, fault: fault?.message, faultLine: fault?.line)
    }
}
