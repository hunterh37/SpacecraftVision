import Foundation

/// Where a flight starts (specs/15 frames and conventions).
public enum CraftStart: Codable, Sendable, Hashable {
    /// On the pad, engine off, upright.
    case pad
    /// Catapult air start at (0, 0, altitude), heading, speed, wings level, throttle 0.5.
    case air(altitude: Double, speed: Double, heading: Double)

    public var isAir: Bool { if case .air = self { true } else { false } }
}

/// Course obstacle with a signed distance field (positive outside), position over time and RealityHD prop id.
public struct Obstacle: Codable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Codable, Sendable { case wall, pylon, pillar, balloon, debris }

    public var id: String
    public var kind: Kind
    /// Wall: centre of the slab (z at mid height). Pylon and pillar: base centre. Balloon: centre at t = 0.
    /// Debris: listed position, reached at `refTime`.
    public var centre: Vec3
    /// Wall length, height and thickness; pylon and pillar height in `height`.
    public var length: Double = 0
    public var height: Double = 0
    public var thickness: Double = 0
    /// Wall runs along y instead of x.
    public var alongY: Bool = false
    /// Wall slot centre (offset along the wall from its centre) and width; nil for a solid wall.
    public var slotCentre: Double?
    public var slotWidth: Double?
    public var radius: Double = 0
    /// Balloon motion: x = centre.x + amplitude * sin(2 pi t / period + phase).
    public var amplitude: Double = 0
    public var period: Double = 0
    public var phase: Double = 0
    /// Debris drift velocity and spin.
    public var drift: Vec3 = .zero
    public var spin: Double = 0
    public var refTime: Double = 0

    public init(id: String, kind: Kind, centre: Vec3) { self.id = id; self.kind = kind; self.centre = centre }

    public static func wall(_ id: String, x: Double, y: Double, length: Double, height: Double, thickness: Double,
                            alongY: Bool = false, baseZ: Double = 0, slot: (centre: Double, width: Double)? = nil) -> Obstacle {
        var o = Obstacle(id: id, kind: .wall, centre: Vec3(x, y, baseZ + height / 2))
        o.length = length; o.height = height; o.thickness = thickness; o.alongY = alongY
        o.slotCentre = slot?.centre; o.slotWidth = slot?.width
        return o
    }

    public static func pylon(_ id: String, x: Double, y: Double, radius: Double, height: Double) -> Obstacle {
        var o = Obstacle(id: id, kind: .pylon, centre: Vec3(x, y, 0)); o.radius = radius; o.height = height; return o
    }

    public static func pillar(_ id: String, x: Double, y: Double, radius: Double, height: Double) -> Obstacle {
        var o = Obstacle(id: id, kind: .pillar, centre: Vec3(x, y, 0)); o.radius = radius; o.height = height; return o
    }

    public static func balloon(_ id: String, _ c: Vec3, radius: Double, amplitude: Double, period: Double, phase: Double = 0) -> Obstacle {
        var o = Obstacle(id: id, kind: .balloon, centre: c)
        o.radius = radius; o.amplitude = amplitude; o.period = period; o.phase = phase
        return o
    }

    public static func debris(_ id: String, _ p: Vec3, radius: Double, vx: Double, vy: Double, spin: Double) -> Obstacle {
        var o = Obstacle(id: id, kind: .debris, centre: p)
        o.radius = radius; o.drift = Vec3(vx, vy, 0); o.spin = spin; o.refTime = p.z / 100
        return o
    }

    /// RealityHD prop id (specs/04).
    public var prop: String {
        switch kind {
        case .wall: "gap-wall"; case .pylon: "pylon"; case .pillar: "canyon-wall"; case .balloon: "obstacle-balloon"
        case .debris: "debris-rock"
        }
    }

    public var moving: Bool { kind == .balloon || kind == .debris }

    /// Radar cross-section, m² (debris: projected area; balloon likewise).
    public var rcs: Double { Double.pi * radius * radius }

    public func position(at t: Double) -> Vec3 {
        switch kind {
        case .balloon:
            guard period > 0 else { return centre }
            return centre + Vec3(amplitude * sin(2 * .pi * t / period + phase), 0, 0)
        case .debris: return centre + drift * (t - refTime)
        default: return centre
        }
    }

    public func velocity(at t: Double) -> Vec3 {
        switch kind {
        case .balloon:
            guard period > 0 else { return .zero }
            let w = 2 * Double.pi / period
            return Vec3(amplitude * w * cos(w * t + phase), 0, 0)
        case .debris: return drift
        default: return .zero
        }
    }

    /// Signed distance from p to the obstacle surface at time t (negative inside).
    public func distance(_ p: Vec3, at t: Double) -> Double {
        switch kind {
        case .wall:
            let d = p - centre
            let u = alongY ? d.y : d.x, v = alongY ? d.x : d.y
            let q = Vec3(abs(u) - length / 2, abs(v) - thickness / 2, abs(d.z) - height / 2)
            let outside = simd_len(Vec3(max(q.x, 0), max(q.y, 0), max(q.z, 0)))
            var sd = outside + min(max(q.x, max(q.y, q.z)), 0)
            if let sc = slotCentre, let sw = slotWidth {
                let slot = abs(u - sc) - sw / 2
                sd = max(sd, -slot)
            }
            return sd
        case .pylon, .pillar:
            let dxy = ((p.x - centre.x) * (p.x - centre.x) + (p.y - centre.y) * (p.y - centre.y)).squareRoot() - radius
            let dz = p.z > height ? p.z - height : (p.z < 0 ? -p.z : -min(p.z, height - p.z))
            if dxy > 0 && dz > 0 { return (dxy * dxy + dz * dz).squareRoot() }
            return max(dxy, dz)
        case .balloon, .debris:
            return simd_len(p - position(at: t)) - radius
        }
    }
}

/// Canyon walls either side of a plan-view centreline (specs/15 C5).
public struct Canyon: Codable, Sendable, Hashable {
    public var centreline: [Vec3]
    public var offset: Double
    public var height: Double

    public init(centreline: [Vec3], offset: Double, height: Double) {
        self.centreline = centreline; self.offset = offset; self.height = height
    }

    /// Signed distance to the nearer wall face (positive inside the channel, below the rim).
    public func distance(_ p: Vec3) -> Double {
        let d = Corridor.polylineDistance2D(p, centreline)
        let inner = offset - d
        if p.z > height { return max(inner, p.z - height) }
        return inner
    }
}

public extension Course {
    /// Signed distance from p to the nearest obstacle or canyon wall, with the obstacle id.
    func nearestObstacle(_ p: Vec3, at t: Double) -> (id: String, distance: Double)? {
        var best: (String, Double)?
        for o in obstacles {
            let d = o.distance(p, at: t)
            if best == nil || d < best!.1 { best = (o.id, d) }
        }
        if let c = canyon {
            let d = c.distance(p)
            if best == nil || d < best!.1 { best = ("canyon wall", d) }
        }
        return best
    }

    /// Signed distance to the nearest gate torus (planes y = const).
    func nearestGate(_ p: Vec3) -> Double? {
        gates.map { g in
            let dx = p.x - g.centre.x, dz = p.z - g.centre.z, dy = p.y - g.centre.y
            let ring = (dx * dx + dz * dz).squareRoot() - (g.innerRadius + g.tubeRadius)
            return (ring * ring + dy * dy).squareRoot() - g.tubeRadius
        }.min()
    }

    /// Sphere-traced ray from origin along unit dir, up to maxRange; distance to the first hit or nil.
    func raycast(from o: Vec3, dir: Vec3, maxRange: Double, at t: Double, includeGates: Bool = false) -> Double? {
        var s = 0.0
        for _ in 0..<96 {
            let p = o + dir * s
            var dist = nearestObstacle(p, at: t)?.distance ?? .infinity
            if includeGates, let g = nearestGate(p) { dist = min(dist, g) }
            guard dist.isFinite else { return nil }
            if dist < 0.05 { return s }
            let n = (id: "", distance: dist)
            s += max(n.distance, 0.05)
            if s > maxRange { return nil }
        }
        return nil
    }

    static let c2b = Course(id: "C2B", extent: Vec3(400, 1000, 120),
                            corridor: .box(from: .zero, to: Vec3(0, 900, 0), halfWidth: 70, floor: 15, ceiling: 90, floorGrace: 15),
                            gates: [Gate("G1", Vec3(0, 100, 40), r: 12), Gate("G2", Vec3(0, 850, 40), r: 12)],
                            finishY: 870, landingZone: nil, wind: .calm, timeOfDay: .golden, goal: Vec3(0, 870, 40),
                            obstacles: [
                                .wall("W1", x: 0, y: 250, length: 200, height: 100, thickness: 2, slot: (25, 18)),
                                .wall("W2", x: 0, y: 450, length: 200, height: 100, thickness: 2, slot: (-30, 18)),
                                .wall("W3", x: 0, y: 650, length: 200, height: 100, thickness: 2, slot: (10, 18)),
                            ])

    static let c3 = Course(id: "C3", extent: Vec3(400, 1300, 400),
                           corridor: .box(from: .zero, to: Vec3(0, 1150, 0), halfWidth: 90, floor: 60, ceiling: 400, floorGrace: 20),
                           gates: [Gate("G1", Vec3(0, 200, 150), r: 15), Gate("G2", Vec3(40, 400, 200), r: 15),
                                   Gate("G3", Vec3(-30, 600, 250), r: 15), Gate("G4", Vec3(60, 800, 300), r: 15),
                                   Gate("G5", Vec3(0, 1000, 300), r: 15)],
                           finishY: 1100, landingZone: nil, wind: Wind(fromDeg: 270, speed: 8, gustSigma: 2.0, seed: 3303),
                           timeOfDay: .afternoon, goal: Vec3(0, 1100, 300))

    static let c4 = Course(id: "C4", extent: Vec3(600, 1800, 260),
                           corridor: .box(from: .zero, to: Vec3(0, 1700, 0), halfWidth: 250, floor: 30, ceiling: 220, floorGrace: 0),
                           gates: [Gate("F", Vec3(0, 1600, 120), r: 15)], finishY: 1600, landingZone: nil,
                           wind: Wind(fromDeg: 0, speed: 3, gustSigma: 1.0, seed: 4404), timeOfDay: .afternoon,
                           goal: Vec3(0, 1600, 120), start: .air(altitude: 120, speed: 35, heading: 0),
                           obstacles: [
                               .wall("W1", x: -30, y: 400, length: 200, height: 250, thickness: 3),
                               .wall("W2", x: 40, y: 800, length: 240, height: 250, thickness: 3),
                               .wall("W3a", x: 0, y: 1200, length: 160, height: 250, thickness: 3),
                               .wall("W3b", x: 80, y: 1160, length: 80, height: 250, thickness: 3, alongY: true),
                               .pylon("P1", x: -150, y: 250, radius: 1.5, height: 150),
                               .pylon("P2", x: 120, y: 300, radius: 1.5, height: 150),
                               .pylon("P3", x: -60, y: 600, radius: 1.5, height: 150),
                               .pylon("P4", x: 150, y: 650, radius: 1.5, height: 150),
                               .pylon("P5", x: -180, y: 900, radius: 1.5, height: 150),
                               .pylon("P6", x: 60, y: 1000, radius: 1.5, height: 150),
                               .pylon("P7", x: -120, y: 1400, radius: 1.5, height: 150),
                               .pylon("P8", x: 130, y: 1450, radius: 1.5, height: 150),
                           ])

    static let c5Centreline: [Vec3] = [Vec3(0, 0, 0), Vec3(0, 400, 0), Vec3(150, 800, 0), Vec3(150, 1200, 0),
                                       Vec3(-100, 1600, 0), Vec3(-100, 2000, 0), Vec3(0, 2400, 0)]

    static let c5 = Course(id: "C5", extent: Vec3(700, 2600, 220),
                           corridor: .path(points: c5Centreline, halfWidth: 70, floor: 20, ceiling: 180, floorGrace: 0),
                           gates: [Gate("F", Vec3(0, 2400, 80), r: 15)], finishY: 2400, landingZone: nil,
                           wind: Wind(fromDeg: 180, speed: 4, gustSigma: 2.0, seed: 5505), timeOfDay: .golden,
                           goal: Vec3(0, 2400, 80), start: .air(altitude: 80, speed: 32, heading: 0),
                           obstacles: [
                               .pillar("H1", x: -30, y: 300, radius: 12, height: 200),
                               .pillar("H2", x: 110, y: 750, radius: 12, height: 200),
                               .pillar("H3", x: 180, y: 1050, radius: 10, height: 200),
                               .pillar("H4", x: -40, y: 1500, radius: 12, height: 200),
                               .pillar("H5", x: -130, y: 1850, radius: 10, height: 200),
                               .pillar("H6", x: 20, y: 2250, radius: 12, height: 200),
                               .balloon("B1", Vec3(0, 600, 80), radius: 5, amplitude: 50, period: 60),
                               .balloon("B2", Vec3(150, 1000, 90), radius: 5, amplitude: 50, period: 60, phase: 1.5),
                               .balloon("B3", Vec3(25, 1400, 70), radius: 5, amplitude: 50, period: 45),
                               .balloon("B4", Vec3(-100, 1800, 85), radius: 5, amplitude: 50, period: 45, phase: 3.0),
                           ],
                           canyon: Canyon(centreline: c5Centreline, offset: 70, height: 200))

    /// (x, y, z, r, vx, vy, spin) from specs/15 C6.
    static let c6Debris: [(Double, Double, Double, Double, Double, Double, Double)] = [
        (94, 19, 1946, 5.5, 17.9, -3.5, 0.48), (4, -1, 2206, 7.9, 16.4, 14.6, 0.72), (-104, -65, 2286, 4.5, 19.0, 5.6, 0.32),
        (30, -135, 2455, 7.6, -7.4, -1.5, 0.89), (-44, -127, 2545, 5.3, 11.7, -5.2, 0.58), (-9, 45, 2785, 7.4, 13.9, -8.1, 0.65),
        (164, 186, 2856, 4.7, -18.8, -9.8, 0.45), (71, -114, 3023, 6.6, 24.5, -3.8, 0.91), (-14, -21, 3223, 3.9, 4.8, 20.6, 0.81),
        (44, -10, 3339, 4.5, -7.3, -20.2, 0.71), (3, -122, 3487, 6.3, -17.0, 8.6, 0.45), (-66, 4, 3628, 7.1, -7.4, 6.7, 0.90),
        (48, 45, 3778, 2.1, -1.5, -20.3, 0.37), (86, 36, 3950, 5.8, 17.0, 13.8, 0.92), (75, -168, 4131, 4.9, 0.8, 9.3, 0.84),
        (38, -99, 4292, 3.6, -12.0, -17.1, 0.85), (146, -150, 4358, 3.3, 13.9, -10.7, 0.77), (-8, 4, 4600, 2.7, -1.5, 12.8, 0.38),
        (15, -20, 4736, 6.5, 7.6, 16.1, 0.95), (-139, -33, 4801, 3.3, 5.3, 4.5, 0.82), (-75, -117, 5043, 5.5, 8.0, -4.0, 0.64),
        (108, 21, 5127, 6.3, -17.5, -0.2, 0.62), (36, 240, 5351, 6.7, 22.3, 7.7, 0.20), (4, 148, 5510, 2.7, -7.7, -5.1, 0.82),
        (-118, -14, 5633, 2.6, -9.7, 2.7, 0.43), (136, 143, 5760, 3.1, 3.5, -6.7, 0.14), (27, -23, 5933, 7.4, -3.2, -13.2, 0.35),
        (140, 57, 6094, 3.9, 9.9, 7.1, 0.36), (-42, 107, 6245, 5.2, 13.2, 18.0, 0.25), (90, 122, 6362, 4.0, -7.6, 1.1, 0.45),
        (233, 67, 6540, 4.8, 2.4, 5.0, 0.68), (-8, -38, 6680, 7.0, 11.5, -2.8, 0.12), (6, -85, 6823, 5.1, 4.8, 23.0, 0.44),
        (-42, -135, 6972, 8.0, -3.8, 12.5, 0.71), (84, 60, 7064, 7.6, 14.4, -17.6, 0.12), (-34, 40, 7270, 2.7, -17.2, -5.1, 0.31),
        (-108, -32, 7343, 3.1, -18.1, -14.2, 0.73), (116, 113, 7509, 6.8, -2.3, 5.8, 0.95), (-119, 150, 7705, 3.7, 17.3, 4.8, 0.21),
        (-26, 91, 7816, 2.4, 0.7, -21.5, 0.65),
    ]

    static let c6 = Course(id: "C6", extent: Vec3(3000, 3000, 10500),
                           corridor: .tube(from: .zero, to: Vec3(0, 0, 10500), radius: 1500),
                           gates: [], finishY: nil, landingZone: nil,
                           // 6 m/s at 10 m with power-law shear reaches ~16 m/s at 5 km; the course keeps the shared 0.14 exponent.
                           wind: Wind(fromDeg: 270, speed: 6, gustSigma: 1.0, seed: 6006), timeOfDay: .morning,
                           goal: Vec3(0, 0, 10000),
                           obstacles: c6Debris.enumerated().map { i, d in
                               .debris(String(format: "D%02d", i + 1), Vec3(d.0, d.1, d.2), radius: d.3, vx: d.4, vy: d.5, spin: d.6)
                           },
                           finishZ: 10000)
}

/// Capstone course generator (specs/15 C7). Deterministic in the seed.
public enum CourseGenerator {
    struct RNG {
        var s: UInt64
        mutating func next() -> UInt64 {
            s &+= 0x9E37_79B9_7F4A_7C15
            var z = s
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
        mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * unit() }
        mutating func int(_ a: Int, _ b: Int) -> Int { a + Int(next() % UInt64(b - a + 1)) }
    }

    public static func c7(seed: UInt64) -> Course {
        var r = RNG(s: seed &* 2_654_435_761 &+ 7)
        let length = Double(r.int(15, 25)) * 100
        let windDir = r.range(0, 360), windSpeed = r.range(0, 6)
        let wind = Wind(fromDeg: windDir, speed: windSpeed, gustSigma: 1.0, seed: seed)
        if seed % 2 == 0 {
            // Field family.
            var obstacles: [Obstacle] = []
            let walls = r.int(3, 5)
            var y = 0.0
            var side = r.unit() < 0.5 ? -1.0 : 1.0
            var wallSpans: [(Double, Double, Double)] = []
            for k in 0..<walls {
                y += r.range(300, 450)
                if y > length - 150 { break }
                let len = r.range(120, 240)
                let off = side * r.range(20, 60)
                obstacles.append(.wall("W\(k + 1)", x: off, y: y, length: len, height: 250, thickness: 3))
                wallSpans.append((off - len / 2, off + len / 2, y))
                side = -side
            }
            let pylons = r.int(6, 10)
            var n = 0, tries = 0
            while n < pylons && tries < 200 {
                tries += 1
                let p = Vec3(r.range(-220, 220), r.range(150, length - 100), 0)
                let clear = wallSpans.allSatisfy { w in
                    let dx = max(w.0 - p.x, 0, p.x - w.1)
                    return (dx * dx + (p.y - w.2) * (p.y - w.2)).squareRoot() >= 60
                }
                guard clear else { continue }
                n += 1
                obstacles.append(.pylon("P\(n)", x: p.x, y: p.y, radius: 1.5, height: 150))
            }
            return Course(id: "C7-\(seed)", extent: Vec3(600, length + 200, 260),
                          corridor: .box(from: .zero, to: Vec3(0, length + 100, 0), halfWidth: 250, floor: 30, ceiling: 220, floorGrace: 0),
                          gates: [Gate("F", Vec3(0, length, 120), r: 15)], finishY: length, landingZone: nil,
                          wind: wind, timeOfDay: .afternoon, goal: Vec3(0, length, 120),
                          start: .air(altitude: 120, speed: 35, heading: 0), obstacles: obstacles, seed: seed)
        }
        // Canyon family.
        let segments = r.int(5, 7)
        let hw = r.range(60, 80)
        var pts: [Vec3] = [.zero]
        var heading = 0.0
        let segLen = length / Double(segments)
        for k in 0..<segments {
            if k > 0 { heading += (r.unit() < 0.5 ? -1 : 1) * r.range(15, 30) * .pi / 180 }
            heading = min(max(heading, -0.6), 0.6)
            let last = pts.last!
            pts.append(last + Vec3(sin(heading) * segLen, cos(heading) * segLen, 0))
        }
        let end = pts.last!
        var obstacles: [Obstacle] = []
        func pointAlong(_ f: Double) -> (Vec3, Vec3) {
            let s = f * Double(segments)
            let i = min(Int(s), segments - 1)
            let a = pts[i], b = pts[i + 1], u = s - Double(i)
            let dir = (b - a) / max(simd_len(b - a), 1e-6)
            return (a + (b - a) * u, Vec3(dir.y, -dir.x, 0))
        }
        let pillars = r.int(4, 6)
        var placed: [Vec3] = []
        var tries = 0
        while placed.count < pillars && tries < 200 {
            tries += 1
            let (c, n) = pointAlong(r.range(0.12, 0.92))
            let p = c + n * r.range(-hw * 0.6, hw * 0.6)
            guard placed.allSatisfy({ simd_len($0 - p) >= 50 }) else { continue }
            placed.append(p)
            obstacles.append(.pillar("H\(placed.count)", x: p.x, y: p.y, radius: r.range(10, 12), height: 200))
        }
        let balloons = r.int(3, 5)
        for k in 0..<balloons {
            let (c, _) = pointAlong(r.range(0.15, 0.9))
            obstacles.append(.balloon("B\(k + 1)", Vec3(c.x, c.y, r.range(70, 90)), radius: 5,
                                      amplitude: r.range(30, 60), period: r.range(40, 70), phase: r.range(0, 2 * .pi)))
        }
        return Course(id: "C7-\(seed)", extent: Vec3(800, length + 200, 220),
                      corridor: .path(points: pts, halfWidth: hw, floor: 20, ceiling: 180, floorGrace: 0),
                      gates: [Gate("F", Vec3(end.x, end.y, 80), r: 15)], finishY: end.y, landingZone: nil,
                      wind: wind, timeOfDay: .golden, goal: Vec3(end.x, end.y, 80),
                      start: .air(altitude: 80, speed: 32, heading: 0), obstacles: obstacles,
                      canyon: Canyon(centreline: pts, offset: hw, height: 200), seed: seed)
    }
}
