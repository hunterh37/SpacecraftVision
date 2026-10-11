import Foundation
import SpacecraftCore
import FlightSim
import FlightCode

/// Result of a headless preview or completed flight, Sendable for UI and analysis.
public struct FlightReport: Sendable, Hashable {
    public var result: FlightResult
    public var samples: [FlightSample]
    public var series: [String: [Double]]
    public var seriesTime: [String: [Double]]
    public var events: [String]
    public var faults: [String]
    public var compileError: CompileError?
}

public enum FlightPreview {
    /// Compile and simulate a full flight headless. Returns nil result with a compile error when code fails to compile.
    public static func run(source: String, craft: CraftDesign, mission: Mission, seed: UInt64 = 1) -> FlightReport {
        let sim = FlightSimulation(craft: craft, mission: mission, seed: seed)
        do {
            let g = try ScriptGuidance(source: source)
            g.attach(to: sim)
        } catch let e as CompileError {
            let empty = FlightResult(passed: false, failure: nil, duration: 0, apogee: 0, fuelUsed: 0, gatesPassed: 0,
                                     minClearance: nil, pitchRMSDeg: nil, score: 0)
            return FlightReport(result: empty, samples: [], series: [:], seriesTime: [:], events: [], faults: [], compileError: e)
        } catch {
            fatalError("unexpected \(error)")
        }
        let r = sim.runToEnd()
        return report(sim, r)
    }

    public static func report(_ sim: FlightSimulation, _ r: FlightResult) -> FlightReport {
        FlightReport(result: r, samples: sim.samples, series: sim.userSeries.mapValues { $0.map(\.v) },
                     seriesTime: sim.userSeries.mapValues { $0.map(\.t) },
                     events: sim.events.map { String(format: "%.1f s  %@", $0.t, $0.text) },
                     faults: sim.faultMessages.prefix(20).map { "Line \($0.line): \($0.message)" }, compileError: nil)
    }
}
