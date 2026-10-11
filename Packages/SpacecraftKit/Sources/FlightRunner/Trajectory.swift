import Foundation
import simd
import SpacecraftCore
import FlightSim

/// One decimated point of a flown or forecast path.
public struct TrajectoryPoint: Sendable, Hashable {
    public var t: Double
    public var position: Vec3
    public var speed: Double
}

/// A labelled moment on the path: a flight event, the apogee, a gate, the landing or the failure point.
public struct TrajectoryPin: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable { case event, apogee, failure, landing, gate(passed: Bool) }
    public var id: Int
    public var t: Double
    public var label: String
    public var position: Vec3
    public var kind: Kind
}

/// Everything the space view needs to draw a flight, independent of RealityKit so it can be tested headless.
public struct TrajectoryLayout: Sendable {
    public var points: [TrajectoryPoint]
    public var pins: [TrajectoryPin]
    public var minBound: Vec3
    public var maxBound: Vec3
    public var maxSpeed: Double
    public var apexIndex: Int

    public static let empty = TrajectoryLayout(points: [], pins: [], minBound: .zero, maxBound: .zero, maxSpeed: 1, apexIndex: 0)

    public var duration: Double { points.last?.t ?? 0 }
    /// Longest side of the path's bounding box, metres.
    public var extent: Double { max(maxBound.x - minBound.x, maxBound.y - minBound.y, maxBound.z - minBound.z, 1) }
    public var centre: Vec3 { (minBound + maxBound) / 2 }

    /// `"12.3 s  Engine cutoff"` lines (as stored in `FlightReport.events`) to `(t, text)`.
    public static func parseEvents(_ lines: [String]) -> [(t: Double, text: String)] {
        lines.compactMap { line in
            guard let r = line.range(of: " s  "), let t = Double(line[..<r.lowerBound]) else { return nil }
            return (t, String(line[r.upperBound...]))
        }
    }

    public static func make(samples: [FlightSample], events: [(t: Double, text: String)], result: FlightResult?, gates: [Gate] = [], maxPoints: Int = 260) -> TrajectoryLayout {
        guard !samples.isEmpty else { return .empty }
        let apex = samples.indices.max { samples[$0].position.z < samples[$1].position.z } ?? 0
        let step = max(1, (samples.count + maxPoints - 1) / max(maxPoints, 2))
        var keep = Set(stride(from: 0, to: samples.count, by: step))
        keep.insert(samples.count - 1); keep.insert(apex)
        let points = keep.sorted().map { TrajectoryPoint(t: samples[$0].t, position: samples[$0].position, speed: samples[$0].speed) }
        var lo = points[0].position, hi = points[0].position
        for p in points { lo = simd_min(lo, p.position); hi = simd_max(hi, p.position) }
        for g in gates { lo = simd_min(lo, g.centre - Vec3(repeating: g.innerRadius)); hi = simd_max(hi, g.centre + Vec3(repeating: g.innerRadius)) }
        var layout = TrajectoryLayout(points: points, pins: [], minBound: lo, maxBound: hi, maxSpeed: max(points.map(\.speed).max() ?? 1, 1),
                                      apexIndex: points.firstIndex { $0.t == samples[apex].t } ?? 0)
        var pins: [TrajectoryPin] = []
        func add(_ t: Double, _ label: String, _ pos: Vec3, _ kind: TrajectoryPin.Kind) { pins.append(TrajectoryPin(id: pins.count, t: t, label: label, position: pos, kind: kind)) }
        var seen = Set<String>()
        for e in events where pins.filter({ $0.kind == .event }).count < 8 {
            guard seen.insert(e.text).inserted else { continue }
            add(e.t, e.text, layout.position(at: e.t), .event)
        }
        add(points[layout.apexIndex].t, "Apogee \(Int(points[layout.apexIndex].position.z.rounded())) m", points[layout.apexIndex].position, .apogee)
        for (i, g) in gates.enumerated() { add(0, g.id, g.centre, .gate(passed: i < (result?.gatesPassed ?? 0))) }
        if let f = result?.failure, let last = points.last { add(last.t, f.title, last.position, .failure) }
        else if result?.passed == true, let last = points.last { add(last.t, "Landed", last.position, .landing) }
        layout.pins = pins
        return layout
    }

    /// Linear interpolation along the path; clamps outside the flight.
    public func position(at t: Double) -> Vec3 {
        guard let first = points.first, let last = points.last else { return .zero }
        if t <= first.t { return first.position }
        if t >= last.t { return last.position }
        var lo = 0, hi = points.count - 1
        while hi - lo > 1 { let mid = (lo + hi) / 2; if points[mid].t <= t { lo = mid } else { hi = mid } }
        let a = points[lo], b = points[hi], f = (t - a.t) / max(b.t - a.t, 1e-9)
        return a.position + (b.position - a.position) * f
    }

    /// Index of the last point at or before `t`.
    public func index(at t: Double) -> Int {
        var lo = 0, hi = points.count - 1
        while lo < hi { let mid = (lo + hi + 1) / 2; if points[mid].t <= t { lo = mid } else { hi = mid - 1 } }
        return lo
    }
}

/// Plain-language answer to "did the code work?" with the reasons.
public struct FlightVerdict: Sendable, Hashable {
    public enum State: Sendable, Hashable { case noFlight, flying, worked, failed }
    public struct Fact: Sendable, Hashable { public var label: String; public var value: String }

    public var state: State
    public var headline: String
    public var detail: String
    /// Source line to open when the failure points at the code.
    public var line: Int?
    public var facts: [Fact]
    /// Whether the forecast made before launch matched what happened.
    public var forecastNote: String?

    public static func make(live: Bool, result: FlightResult?, faults: [String], forecast: FlightReport?, gateCount: Int = 0) -> FlightVerdict {
        guard let r = result else {
            if live { return FlightVerdict(state: .flying, headline: "FLYING", detail: "Your code is steering the craft now.", line: nil, facts: [], forecastNote: nil) }
            if let f = forecast, f.compileError == nil {
                let says = f.result.passed ? "pass" : "fail: \(f.result.failure?.title ?? "unknown")"
                return FlightVerdict(state: .noFlight, headline: "NO FLIGHT YET", detail: "The forecast says this code will \(says).", line: f.result.failure?.line, facts: [], forecastNote: nil)
            }
            return FlightVerdict(state: .noFlight, headline: "NO FLIGHT YET", detail: "Launch to see the path your code flies.", line: nil, facts: [], forecastNote: nil)
        }
        var facts = [Fact(label: "APOGEE", value: "\(Int(r.apogee.rounded())) m"), Fact(label: "FLIGHT", value: String(format: "%.1f s", r.duration)),
                     Fact(label: "FUEL", value: String(format: "%.1f kg", r.fuelUsed))]
        if gateCount > 0 { facts.append(Fact(label: "GATES", value: "\(r.gatesPassed) / \(gateCount)")) }
        if let c = r.minClearance { facts.append(Fact(label: "CLEARANCE", value: String(format: "%.1f m", c))) }
        var note: String?
        if let f = forecast, f.compileError == nil {
            let same = f.result.passed == r.passed && abs(f.result.apogee - r.apogee) < 2
            note = same ? "Matches the forecast." : "Differs from the forecast. The code changed after it was made, or wind moved the path."
        }
        if r.passed {
            return FlightVerdict(state: .worked, headline: "CODE WORKED", detail: "The mission passed.", line: nil, facts: facts, forecastNote: note)
        }
        let fault = faults.first
        let faultLine = fault.flatMap { f -> Int? in f.hasPrefix("Line ") ? Int(f.dropFirst(5).prefix { $0.isNumber }) : nil }
        let title = r.failure?.title ?? "Did not pass"
        let body = r.failure?.body ?? ""
        return FlightVerdict(state: .failed, headline: "CODE DID NOT PASS", detail: "\(title). \(body)".trimmingCharacters(in: .whitespaces),
                             line: r.failure?.line ?? faultLine, facts: facts, forecastNote: note)
    }
}
