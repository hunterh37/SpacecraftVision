import Foundation

public typealias Vec3 = SIMD3<Double>

public enum TimeOfDay: String, Codable, Sendable { case morning, afternoon, golden
    public var ambientK: Double { switch self { case .morning: 295; case .afternoon: 305; case .golden: 300 } }
}

public struct Gate: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var centre: Vec3
    public var innerRadius: Double
    /// Gate plane is y = centre.y (all v1 rocket gates face north).
    public init(_ id: String, _ c: Vec3, r: Double) { self.id = id; centre = c; innerRadius = r }
    /// Tube radius of the torus: authored 8 m outer diameter at r = 3.5, uniform scale.
    public var tubeRadius: Double { 0.5 * innerRadius / 3.5 }
}

public enum Corridor: Codable, Sendable, Hashable {
    case tube(from: Vec3, to: Vec3, radius: Double)
    case box(from: Vec3, to: Vec3, halfWidth: Double, floor: Double, ceiling: Double, floorGrace: Double)
    /// Plan-view polyline with half width, floor and ceiling (canyon courses).
    case path(points: [Vec3], halfWidth: Double, floor: Double, ceiling: Double, floorGrace: Double)

    /// Whether a point is inside at time t.
    public func contains(_ p: Vec3, time t: Double) -> Bool {
        switch self {
        case let .tube(a, b, r):
            return Corridor.segmentDistance(p, a, b) <= r || p.z < 0.5
        case let .box(a, b, hw, floor, ceiling, grace):
            let a2 = Vec3(a.x, a.y, 0), b2 = Vec3(b.x, b.y, 0), p2 = Vec3(p.x, p.y, 0)
            if Corridor.segmentDistance(p2, a2, b2) > hw { return false }
            if p.z > ceiling { return false }
            if t > grace && p.z < floor { return false }
            return true
        case let .path(points, hw, floor, ceiling, grace):
            if Corridor.polylineDistance2D(p, points) > hw { return false }
            if p.z > ceiling { return false }
            if t > grace && p.z < floor { return false }
            return true
        }
    }

    public static func polylineDistance2D(_ p: Vec3, _ pts: [Vec3]) -> Double {
        let p2 = Vec3(p.x, p.y, 0)
        var best = Double.infinity
        for (a, b) in zip(pts, pts.dropFirst()) {
            best = min(best, segmentDistance(p2, Vec3(a.x, a.y, 0), Vec3(b.x, b.y, 0)))
        }
        return best
    }

    public static func segmentDistance(_ p: Vec3, _ a: Vec3, _ b: Vec3) -> Double {
        let ab = b - a, l2 = simd_dot_d(ab, ab)
        let t = l2 > 0 ? min(max(simd_dot_d(p - a, ab) / l2, 0), 1) : 0
        let q = a + ab * t
        return simd_len(p - q)
    }
}

@inline(__always) public func simd_dot_d(_ a: Vec3, _ b: Vec3) -> Double { (a * b).sum() }
@inline(__always) public func simd_len(_ a: Vec3) -> Double { (a * a).sum().squareRoot() }

public struct Wind: Codable, Sendable, Hashable {
    /// Direction the wind blows from, compass degrees, and speed at 10 m.
    public var fromDeg: Double
    public var speed: Double
    public var gustSigma: Double
    public var seed: UInt64
    public static let calm = Wind(fromDeg: 0, speed: 0, gustSigma: 0, seed: 0)

    /// Steady wind vector at altitude z with power-law shear 0.14.
    public func vector(altitude z: Double) -> Vec3 {
        guard speed > 0 else { return .zero }
        let s = speed * pow(max(z, 1) / 10, 0.14)
        let to = (fromDeg + 180) * .pi / 180
        return Vec3(sin(to) * s, cos(to) * s, 0)
    }
}

public struct LandingZone: Codable, Sendable, Hashable {
    public var centre: Vec3
    public var radius: Double
}

public struct Course: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var extent: Vec3
    public var corridor: Corridor
    public var gates: [Gate]
    /// Finish plane y = finishY; nil when the course has no finish plane.
    public var finishY: Double?
    public var landingZone: LandingZone?
    public var wind: Wind
    public var timeOfDay: TimeOfDay
    public var goal: Vec3
    /// Pad start (rockets) or air start (aircraft).
    public var start: CraftStart = .pad
    /// Static and moving obstacles (specs/15); canyon walls are `canyon`.
    public var obstacles: [Obstacle] = []
    public var canyon: Canyon?
    /// Finish plane z = finishZ (debris climb); nil when unused.
    public var finishZ: Double?
    /// Generator seed for C7 courses.
    public var seed: UInt64?

    public init(id: String, extent: Vec3, corridor: Corridor, gates: [Gate], finishY: Double?, landingZone: LandingZone?,
                wind: Wind, timeOfDay: TimeOfDay, goal: Vec3, start: CraftStart = .pad, obstacles: [Obstacle] = [],
                canyon: Canyon? = nil, finishZ: Double? = nil, seed: UInt64? = nil) {
        self.id = id; self.extent = extent; self.corridor = corridor; self.gates = gates; self.finishY = finishY
        self.landingZone = landingZone; self.wind = wind; self.timeOfDay = timeOfDay; self.goal = goal; self.start = start
        self.obstacles = obstacles; self.canyon = canyon; self.finishZ = finishZ; self.seed = seed
    }

    public static let c1 = Course(id: "C1", extent: Vec3(1000, 1000, 1600),
                                  corridor: .tube(from: .zero, to: Vec3(0, 0, 1500), radius: 400), gates: [], finishY: nil,
                                  landingZone: LandingZone(centre: .zero, radius: 100), wind: .calm, timeOfDay: .morning,
                                  goal: Vec3(0, 0, 1100))
    public static let c1w = Course(id: "C1W", extent: Vec3(1000, 1000, 1600),
                                   // Spec deviation: specs/15 places the zone at (0, 300) r 250 and the tube radius at 500 m, which ignores
                                   // ~450 m of eastward parachute drift in 5 m/s wind. Zone and tube moved downwind.
                                   corridor: .tube(from: .zero, to: Vec3(250, 400, 1500), radius: 650), gates: [], finishY: nil,
                                   landingZone: LandingZone(centre: Vec3(400, 300, 0), radius: 250),
                                   wind: Wind(fromDeg: 270, speed: 5, gustSigma: 1.0, seed: 1101), timeOfDay: .afternoon,
                                   goal: Vec3(0, 300, 1100))
    public static let c2 = Course(id: "C2", extent: Vec3(400, 1300, 400),
                                  corridor: .box(from: .zero, to: Vec3(0, 1150, 0), halfWidth: 90, floor: 60, ceiling: 400,
                                                 floorGrace: 20),
                                  gates: [Gate("G1", Vec3(0, 200, 150), r: 12), Gate("G2", Vec3(40, 400, 200), r: 12),
                                          Gate("G3", Vec3(-30, 600, 250), r: 12), Gate("G4", Vec3(60, 800, 300), r: 12),
                                          Gate("G5", Vec3(0, 1000, 300), r: 12)],
                                  finishY: 1100, landingZone: nil, wind: .calm, timeOfDay: .afternoon,
                                  goal: Vec3(0, 1100, 300))
    public static let all = [c1, c1w, c2, c2b, c3, c4, c5, c6]
    public static func named(_ id: String) -> Course? {
        if let c = all.first(where: { $0.id == id }) { return c }
        if id.hasPrefix("C7-"), let s = UInt64(id.dropFirst(3)) { return CourseGenerator.c7(seed: s) }
        return nil
    }
}

public enum MissionGoal: Codable, Sendable, Hashable {
    /// Apogee window plus landing in the zone.
    case hop(apogeeMin: Double, apogeeMax: Double, pitchRMSDeg: Double?)
    /// All gates in order and finish crossed.
    case gates
    /// Reach the finish plane z = course.finishZ inside the corridor.
    case climb
    /// Finish gate passed; scored on energy and time (lesson 10).
    case capstone
}

public struct Mission: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public var lesson: Int?
    public var courseId: String
    public var payloadMass: Double
    public var massCap: Double
    public var partCap: Int
    public var budget: Int
    public var energyCap: Double
    public var fixedFuelLoad: Double?
    public var allowedParts: [String]
    public var goal: MissionGoal
    public var parFuel: Double
    public var parClearance: Double?

    public var course: Course { Course.named(courseId)! }

    static let m1Parts = ["probe-core", "imu", "battery-pack", "nose-cone", "fuel-tank-s", "engine-liquid-small",
                          "fin-trapezoid", "parachute"]

    public static let m1 = Mission(id: "M1", title: "Hop", lesson: 0, courseId: "C1", payloadMass: 20, massCap: 450,
                                   partCap: 12, budget: 20_000, energyCap: 2_500, fixedFuelLoad: 0.10,
                                   allowedParts: m1Parts, goal: .hop(apogeeMin: 1000, apogeeMax: 1200, pitchRMSDeg: nil),
                                   parFuel: 34, parClearance: nil)
    public static let m1w = Mission(id: "M1W", title: "Hop in wind", lesson: 1, courseId: "C1W", payloadMass: 20,
                                    massCap: 450, partCap: 12, budget: 20_000, energyCap: 2_500, fixedFuelLoad: 0.10,
                                    allowedParts: m1Parts, goal: .hop(apogeeMin: 950, apogeeMax: 1200, pitchRMSDeg: 2),
                                    parFuel: 34, parClearance: nil)
    /// Two optional coding challenges on the proven hop course: an open-loop timer and a drag-aware predictor.
    public static let m1t = Mission(id: "M1T", title: "Clockwork hop", lesson: nil, courseId: "C1", payloadMass: 20,
                                    massCap: 450, partCap: 12, budget: 20_000, energyCap: 2_500, fixedFuelLoad: 0.10,
                                    allowedParts: m1Parts, goal: .hop(apogeeMin: 1050, apogeeMax: 1150, pitchRMSDeg: nil),
                                    parFuel: 34.5, parClearance: nil)
    public static let m1p = Mission(id: "M1P", title: "Predictive hop", lesson: nil, courseId: "C1", payloadMass: 35,
                                    massCap: 450, partCap: 12, budget: 19_000, energyCap: 2_500, fixedFuelLoad: 0.10,
                                    allowedParts: m1Parts, goal: .hop(apogeeMin: 1080, apogeeMax: 1120, pitchRMSDeg: nil),
                                    parFuel: 35, parClearance: nil)
    public static let m2 = Mission(id: "M2", title: "Gates", lesson: 2, courseId: "C2", payloadMass: 20, massCap: 1_600,
                                   partCap: 16, budget: 26_000, energyCap: 2_500, fixedFuelLoad: nil,
                                   allowedParts: m1Parts + ["fuel-tank-m", "decoupler"], goal: .gates,
                                   parFuel: 380, parClearance: 6)
    static let m2bParts = m1Parts + ["fuel-tank-m", "decoupler", "lidar-sensor"]
    static let aircraftParts = ["probe-core", "imu", "battery-pack", "nose-cone", "fuselage-section", "engine-prop", "wing-section",
                                "elevon", "fin-trapezoid", "landing-gear", "solar-panel", "lidar-sensor"]

    public static let m2b = Mission(id: "M2B", title: "Gates and walls", lesson: 3, courseId: "C2B", payloadMass: 20, massCap: 1_600,
                                    partCap: 16, budget: 30_000, energyCap: 2_500, fixedFuelLoad: nil, allowedParts: m2bParts,
                                    goal: .gates, parFuel: 220, parClearance: 5)
    public static let m3 = Mission(id: "M3", title: "Drift", lesson: nil, courseId: "C3", payloadMass: 20, massCap: 1_600,
                                   partCap: 16, budget: 26_000, energyCap: 2_500, fixedFuelLoad: nil,
                                   allowedParts: m1Parts + ["fuel-tank-m", "decoupler"], goal: .gates, parFuel: 380, parClearance: 6)
    /// Aircraft missions: `parFuel` is energy in Wh (specs/15 C4 par).
    public static let m4 = Mission(id: "M4", title: "Field", lesson: 4, courseId: "C4", payloadMass: 20, massCap: 600, partCap: 18,
                                   budget: 28_000, energyCap: 5_000, fixedFuelLoad: nil, allowedParts: aircraftParts, goal: .gates,
                                   parFuel: 600, parClearance: 8)
    public static let m5 = Mission(id: "M5", title: "Canyon", lesson: 6, courseId: "C5", payloadMass: 20, massCap: 600, partCap: 18,
                                   budget: 28_000, energyCap: 5_000, fixedFuelLoad: nil, allowedParts: aircraftParts, goal: .gates,
                                   parFuel: 900, parClearance: 20)
    public static let m6 = Mission(id: "M6", title: "Debris", lesson: 7, courseId: "C6", payloadMass: 50, massCap: 3_600, partCap: 20,
                                   budget: 34_000, energyCap: 2_500, fixedFuelLoad: nil,
                                   allowedParts: m2bParts + ["fuel-tank-l", "engine-solid-small", "radar-sensor", "camera-sensor"],
                                   goal: .climb, parFuel: 1_500, parClearance: 40)

    /// Capstone on generated course `C7-<seed>`.
    public static func m7(seed: UInt64) -> Mission {
        Mission(id: "M7-\(seed)", title: "Capstone", lesson: 10, courseId: "C7-\(seed)", payloadMass: 40, massCap: 650, partCap: 20,
                budget: 40_000, energyCap: 7_500, fixedFuelLoad: nil, allowedParts: aircraftParts + ["camera-sensor", "radar-sensor"],
                goal: .capstone, parFuel: 0, parClearance: nil)
    }

    /// True for missions flown by an aircraft (air start).
    public var isAircraft: Bool { course.start.isAir }

    public static let all = [m1, m1w, m1t, m1p, m2, m2b, m3, m4, m5, m6]
    public static func named(_ id: String) -> Mission? {
        if let m = all.first(where: { $0.id == id }) { return m }
        if id.hasPrefix("M7-"), let s = UInt64(id.dropFirst(3)) { return m7(seed: s) }
        return nil
    }
}

/// A launch blocker found in the workshop (specs/07 hard constraints).
public struct LaunchBlocker: Sendable, Hashable {
    public var key: String
    public var title: String
    public var body: String
}

public extension Mission {
    func blockers(for craft: CraftDesign) -> [LaunchBlocker] {
        let s = craft.stats()
        var out: [LaunchBlocker] = []
        if craft.stack.isEmpty || !s.hasCommand {
            out.append(LaunchBlocker(key: "fail.command", title: "No command part", body: "Add a probe core."))
        }
        if s.wetMass > massCap {
            out.append(LaunchBlocker(key: "fail.mass", title: "Too heavy",
                                     body: "Wet mass \(Int(s.wetMass.rounded())) kg is over the mission cap of \(Int(massCap)) kg."))
        }
        let banned = craft.expandedParts.map(\.def.realityHDId).first { !allowedParts.contains($0) }
        if banned != nil || s.partCount > partCap {
            let name = banned.flatMap { PartCatalog.part($0)?.displayName } ?? "A part"
            out.append(LaunchBlocker(key: "fail.part-list", title: "Part not allowed",
                                     body: "\(name) is not on this mission's part list, or the craft has \(s.partCount) parts against a cap of \(partCap)."))
        }
        if s.cost > budget {
            out.append(LaunchBlocker(key: "fail.budget", title: "Over budget",
                                     body: "Craft cost \(s.cost) cr is over the mission budget of \(budget) cr."))
        }
        return out
    }
}
