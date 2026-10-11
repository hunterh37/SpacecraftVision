import Foundation
import simd
import SpacecraftCore
import FlightSim

/// How a flight is drawn: a side profile (downrange vs altitude) for vertical flights, or a top-down map for gate courses.
public enum PathMode: Sendable { case side, top }

/// Maps world positions (x east, y north, z up, metres) to the graph. Pure geometry so it can be tested.
public struct PathProjection: Sendable {
    public let mode: PathMode
    /// Horizontal axis for the side profile: the direction the flight drifts.
    public let dir: SIMD2<Double>
    public let minU: Double, maxU: Double, minV: Double, maxV: Double

    public init(samples: [FlightSample], course: Course) {
        let mode: PathMode = course.gates.isEmpty ? .side : .top
        self.mode = mode
        var d = SIMD2<Double>(1, 0)
        if let a = samples.first?.position, let b = samples.max(by: { hypot($0.position.x, $0.position.y) < hypot($1.position.x, $1.position.y) })?.position {
            let h = SIMD2<Double>(b.x - a.x, b.y - a.y)
            if simd_length(h) > 20 { d = h / simd_length(h) }
        }
        self.dir = d
        var pts: [Vec3] = samples.map(\.position) + [course.goal, .zero]
        if let z = course.landingZone { pts += [z.centre + Vec3(z.radius, 0, 0), z.centre - Vec3(z.radius, 0, 0), z.centre + Vec3(0, z.radius, 0), z.centre - Vec3(0, z.radius, 0)] }
        pts += course.gates.map(\.centre)
        for g in course.gates { pts += [g.centre + Vec3(g.innerRadius, 0, 0), g.centre - Vec3(g.innerRadius, 0, 0)] }
        if case let .tube(a, b, r) = course.corridor { pts += [a, b] ; if mode == .top { pts += [a + Vec3(r, 0, 0), a - Vec3(r, 0, 0), b + Vec3(r, 0, 0), b - Vec3(r, 0, 0)] } }
        let us = pts.map { Self.u($0, mode, d) }, vs = pts.map { Self.v($0, mode) }
        var lo = (us.min() ?? 0, vs.min() ?? 0), hi = (us.max() ?? 1, vs.max() ?? 1)
        let minSpan = mode == .side ? (u: 60.0, v: 120.0) : (u: 120.0, v: 120.0)
        if hi.0 - lo.0 < minSpan.u { let c = (hi.0 + lo.0) / 2; lo.0 = c - minSpan.u / 2; hi.0 = c + minSpan.u / 2 }
        if hi.1 - lo.1 < minSpan.v { let c = (hi.1 + lo.1) / 2; lo.1 = c - minSpan.v / 2; hi.1 = c + minSpan.v / 2 }
        let padU = (hi.0 - lo.0) * 0.08, padV = (hi.1 - lo.1) * 0.10
        minU = lo.0 - padU; maxU = hi.0 + padU; minV = lo.1 - padV; maxV = hi.1 + padV
    }

    /// Side profile: downrange (along the drift direction) by altitude. Top view: north runs left to right, east up the page,
    /// so a long gate course uses the width of the graph.
    static func u(_ p: Vec3, _ mode: PathMode, _ d: SIMD2<Double>) -> Double { mode == .side ? p.x * d.x + p.y * d.y : p.y }
    static func v(_ p: Vec3, _ mode: PathMode) -> Double { mode == .side ? p.z : p.x }

    /// Point in the graph's rectangle `size` (y down).
    public func point(_ p: Vec3, in size: CGSize) -> CGPoint {
        var sx = size.width / (maxU - minU), sy = size.height / (maxV - minV)
        var ox = 0.0, oy = 0.0
        if mode == .top { // true shape: one scale for both axes
            let s = min(sx, sy); ox = (size.width - (maxU - minU) * s) / 2; oy = (size.height - (maxV - minV) * s) / 2; sx = s; sy = s
        }
        let uu = Self.u(p, mode, dir), vv = Self.v(p, mode)
        return CGPoint(x: ox + (uu - minU) * sx, y: size.height - oy - (vv - minV) * sy)
    }

    /// Scale in pixels per metre along each axis, for drawing radii.
    public func scale(in size: CGSize) -> (x: Double, y: Double) {
        let sx = size.width / (maxU - minU), sy = size.height / (maxV - minV)
        return mode == .top ? (min(sx, sy), min(sx, sy)) : (sx, sy)
    }

    /// Index of the sample whose screen position is closest to `location`.
    public func nearest(_ samples: [FlightSample], to location: CGPoint, in size: CGSize) -> Int? {
        guard !samples.isEmpty else { return nil }
        var best = 0, bestD = Double.infinity
        for (i, s) in samples.enumerated() {
            let p = point(s.position, in: size), d = Double((p.x - location.x) * (p.x - location.x) + (p.y - location.y) * (p.y - location.y))
            if d < bestD { bestD = d; best = i }
        }
        return best
    }
}

/// A simulator event with its time, parsed from `FlightReport.events` ("12.3 s  Engine cutoff").
public struct PathEvent: Sendable, Hashable, Identifiable {
    public var id: Int
    public var time: Double
    public var text: String

    public static func parse(_ lines: [String]) -> [PathEvent] {
        lines.enumerated().compactMap { i, l in
            guard let r = l.range(of: " s  "), let t = Double(l[l.startIndex..<r.lowerBound].trimmingCharacters(in: .whitespaces)) else { return nil }
            return PathEvent(id: i, time: t, text: String(l[r.upperBound...]))
        }
    }
}

public extension Array where Element == FlightSample {
    /// The sample closest in time (samples are time ordered).
    func index(atTime t: Double) -> Int? {
        guard !isEmpty else { return nil }
        var lo = 0, hi = count - 1
        while lo < hi { let mid = (lo + hi) / 2; if self[mid].t < t { lo = mid + 1 } else { hi = mid } }
        if lo > 0, abs(self[lo - 1].t - t) < abs(self[lo].t - t) { return lo - 1 }
        return lo
    }
}
