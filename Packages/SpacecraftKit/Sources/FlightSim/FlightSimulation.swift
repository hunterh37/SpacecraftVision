import Foundation
import SpacecraftCore

public struct SplitMix64: Sendable {
    var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    public mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    public mutating func gaussian() -> Double {
        let u1 = max(unit(), 1e-12), u2 = unit()
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}

/// Failure cause shown on the cause card (specs/07, copy from specs/16 `fail.*`).
public struct FlightFailure: Sendable, Hashable, Codable {
    public var key: String
    public var title: String
    public var body: String
    public var time: Double
    public var tick: Int
    public var value: Double
    public var limit: Double
    public var line: Int?
    public init(key: String, title: String, body: String, time: Double, tick: Int, value: Double, limit: Double, line: Int?) {
        self.key = key; self.title = title; self.body = body; self.time = time; self.tick = tick; self.value = value
        self.limit = limit; self.line = line
    }
}

public struct FlightSample: Sendable, Hashable, Codable {
    public var t: Double
    public var position: Vec3
    public var velocity: Vec3
    public var pitch: Double
    public var yaw: Double
    public var throttle: Double
    public var fuel: Double
    public var energy: Double
    public var speed: Double { simd_len(velocity) }
}

public struct FlightResult: Sendable, Hashable, Codable {
    public var passed: Bool
    public var failure: FlightFailure?
    public var duration: Double
    public var apogee: Double
    public var fuelUsed: Double
    public var gatesPassed: Int
    public var minClearance: Double?
    public var pitchRMSDeg: Double?
    public var score: Int
    public init(passed: Bool, failure: FlightFailure?, duration: Double, apogee: Double, fuelUsed: Double, gatesPassed: Int,
                minClearance: Double?, pitchRMSDeg: Double?, score: Int) {
        self.passed = passed; self.failure = failure; self.duration = duration; self.apogee = apogee; self.fuelUsed = fuelUsed
        self.gatesPassed = gatesPassed; self.minClearance = minClearance; self.pitchRMSDeg = pitchRMSDeg; self.score = score
    }
}

public enum GuidanceTickResult: Sendable {
    case ok
    case fault(message: String, line: Int)
}

/// Player code (or a test controller) driven at the 50 Hz guidance rate.
public protocol FlightGuidance: AnyObject {
    func setup(_ sim: FlightSimulation) -> GuidanceTickResult
    func update(_ sim: FlightSimulation, dt: Double) -> GuidanceTickResult
    /// Source line active at the last call, for cause cards.
    var activeLine: Int? { get }
}

/// Deterministic headless flight: point-mass translation at 240 Hz with tracked pitch/yaw/roll attitude,
/// inverse-square gravity, US 1976 atmosphere, per-part drag, engine Isp by ambient pressure, two-stage
/// parachute, wind with shear and seeded gusts, and the failure rules of specs/07.
public final class FlightSimulation {
    public static let physicsRate = 240.0
    public static let guidanceRate = 50.0
    public static let maxDuration = 600.0
    static let mu = 3.986e14, earthR = 6_371_000.0

    public let craft: CraftDesign
    public let mission: Mission
    public let course: Course
    public let seed: UInt64
    public var guidance: FlightGuidance?
    /// Test switch: no atmosphere (vacuum Isp, no drag).
    public var vacuum = false

    // State
    public private(set) var tick = 0
    public private(set) var time = 0.0
    public private(set) var position = Vec3.zero
    public private(set) var velocity = Vec3.zero
    public private(set) var pitch = Double.pi / 2
    public private(set) var yaw = 0.0
    public private(set) var roll = 0.0
    private var rates = Vec3.zero      // pitch, yaw, roll actual rad/s
    public private(set) var rateCommand = Vec3.zero
    public private(set) var throttleCommand = 0.0
    public private(set) var propellant: Double
    public let propellantCapacity: Double
    public private(set) var energyWh: Double
    public let energyCapacity: Double
    public private(set) var chuteStage = 0   // 0 packed, 1 drogue, 2 main, 3 torn
    private var chuteDeployTime = 0.0
    public private(set) var launched = false
    public private(set) var ignited = false
    public private(set) var finished = false
    public private(set) var result: FlightResult?
    public private(set) var apogee = 0.0
    public private(set) var gatesPassed = 0
    public private(set) var minClearance: Double?
    public private(set) var lastLog = ""
    public private(set) var events: [(t: Double, text: String)] = []
    public private(set) var samples: [FlightSample] = []
    public private(set) var userSeries: [String: [(t: Double, v: Double)]] = [:]
    public private(set) var faultMessages: [(line: Int, message: String)] = []
    public var random: SplitMix64
    private var gustRNG: SplitMix64
    private var gust = Vec3.zero
    private var corridorOut = 0.0
    private var skippedTicks = 0
    private var guidanceTicks = 0
    private var pitchErrSq = 0.0, pitchErrN = 0
    private var reachedApogee = false
    private var setupDone = false

    // Craft constants
    let dryMass: Double
    let engines: [EngineSpec]
    let hasFins: Bool
    let parachute: ParachuteSpec?
    let electricDraw: Double
    let bodyCdA: (_ mach: Double, _ firing: Bool) -> Double
    let lowestMaxG: Double
    let finMaxQ: Double?
    public let partIds: Set<String>

    public init(craft: CraftDesign, mission: Mission, seed: UInt64 = 1) {
        self.craft = craft; self.mission = mission; self.course = mission.course; self.seed = seed
        random = SplitMix64(seed: seed)
        gustRNG = SplitMix64(seed: course.wind.seed &+ seed)
        let s = craft.stats()
        dryMass = s.dryMass
        propellant = s.propellantMass; propellantCapacity = craft.expandedParts.reduce(0) { $0 + $1.def.propellantMass }
        energyWh = s.energyWh; energyCapacity = s.energyWh
        let parts = craft.expandedParts
        engines = parts.compactMap { $0.def.realityHDId == "engine-prop" ? nil : $0.def.engine }
        hasFins = parts.contains { $0.def.realityHDId == "fin-trapezoid" }
        parachute = parts.first { $0.def.parachute != nil }?.def.parachute
        electricDraw = parts.reduce(0) { $0 + $1.def.electricDraw }
        lowestMaxG = parts.map(\.def.maxG).min() ?? 50
        finMaxQ = parts.first { $0.def.realityHDId == "fin-trapezoid" }?.def.maxQkPa
        partIds = Set(parts.map(\.def.realityHDId))
        // Frontal: top stack part; stacked parts below: skin friction; annulus steps Cd 0.8; radial parts own CdA.
        let stack = craft.stack.map(\.definition)
        // imu, battery and parachute pack mount inside the probe-core ring (specs/14 drag notes): no drag.
        let inner: Set<String> = ["imu", "battery-pack", "parachute"]
        let radial = parts.filter { $0.def.mount == .radial && !inner.contains($0.def.realityHDId) }.map(\.def)
        bodyCdA = { mach, firing in
            guard let top = stack.first else { return 0 }
            var cda = top.cd(mach: mach) * top.dragArea
            var prevD = top.diameter
            for d in stack.dropFirst() {
                if d.engine != nil && !firing { cda += d.cd(mach: mach) * d.dragArea }
                cda += 0.004 * Double.pi * d.diameter * d.length
                if d.diameter > prevD { cda += 0.8 * Double.pi / 4 * (d.diameter * d.diameter - prevD * prevD) }
                prevD = d.diameter
            }
            for r in radial { cda += r.cd(mach: mach) * r.dragArea }
            return cda
        }
    }

    // MARK: Read-outs used by the craft API

    public var mass: Double { dryMass + propellant }
    public var altitude: Double { position.z }
    public var fuelFraction: Double { propellantCapacity > 0 ? propellant / propellantCapacity : 0 }
    public var energyFraction: Double { energyCapacity > 0 ? energyWh / energyCapacity : 0 }
    public var noseVector: Vec3 { Vec3(cos(pitch) * sin(yaw), cos(pitch) * cos(yaw), sin(pitch)) }
    public var effectiveThrottle: Double {
        guard throttleCommand > 0, propellant > 0 else { return 0 }
        return min(1, max(throttleCommand, engines.map(\.throttleMin).max() ?? 0))
    }
    public var thrustMax: Double {
        let p = Atmosphere.at(altitude: position.z).pressure
        return propellant > 0 ? engines.reduce(0) { $0 + $1.thrust(pressure: p, throttle: 1) } : 0
    }
    public var nextGate: Gate? { gatesPassed < course.gates.count ? course.gates[gatesPassed] : nil }
    public var guidanceTime: Double { max(0, time - 0) }

    /// (bearing relative to yaw, elevation, distance) toward a point.
    public func relative(to p: Vec3) -> (Double, Double, Double) {
        let d = p - position
        let h = (d.x * d.x + d.y * d.y).squareRoot()
        let bearing = wrapAngle(atan2(d.x, d.y) - yaw)
        return (bearing, atan2(d.z, h), simd_len(d))
    }

    // MARK: Commands

    public func setThrottle(_ x: Double) { throttleCommand = min(max(x, 0), 1) }
    public func setPitchRate(_ r: Double) { rateCommand.x = min(max(r, -0.5), 0.5) }
    public func setYawRate(_ r: Double) { rateCommand.y = min(max(r, -0.5), 0.5) }
    public func setRollRate(_ r: Double) { rateCommand.z = min(max(r, -1), 1) }
    public func log(_ s: String) { lastLog = s }
    public func plot(_ name: String, _ v: Double) {
        userSeries[name, default: []].append((time, v))
    }
    public func recordFault(line: Int, message: String) {
        if faultMessages.count < 200 { faultMessages.append((line, message)) }
    }

    /// Fire the next stage item: parachute drogue, then main.
    public func stage() {
        guard let chute = parachute else { event("Stage: nothing to fire"); return }
        let air = simd_len(velocity - wind(at: position.z))
        switch chuteStage {
        case 0:
            if air > chute.drogueLimit { chuteStage = 3; event("Drogue torn at \(Int(air)) m/s") }
            else { chuteStage = 1; chuteDeployTime = time; event("Drogue deployed") }
        case 1:
            if air > chute.mainLimit { chuteStage = 3; event("Main torn at \(Int(air)) m/s") }
            else { chuteStage = 2; chuteDeployTime = time; event("Main deployed") }
        default: event("Stage: nothing to fire")
        }
    }

    func event(_ s: String) { events.append((time, s)) }

    // MARK: Stepping

    /// Run to completion (preview / tests).
    public func runToEnd() -> FlightResult {
        while !finished { step() }
        return result!
    }

    /// Advance n physics steps (live flight).
    public func advance(steps n: Int) { for _ in 0..<n where !finished { step() } }

    func wind(at z: Double) -> Vec3 {
        guard launched || z > 0 else { return .zero }
        return course.wind.vector(altitude: z) + gust
    }

    public func step() {
        guard !finished else { return }
        let dt = 1 / Self.physicsRate
        if !setupDone {
            setupDone = true
            if let g = guidance, case let .fault(msg, line) = g.setup(self) { recordFault(line: line, message: msg) }
        }
        // Guidance at 50 Hz: tick k fires when floor(k * 50 / 240) advances.
        if tick == 0 || (tick * 50) / 240 != ((tick - 1) * 50) / 240 {
            runGuidance()
            if finished { return }
        }

        var atm = Atmosphere.at(altitude: position.z)
        if vacuum { atm.pressure = 0; atm.density = 0 }
        // Gusts: first-order Gauss-Markov, 2 s correlation, seeded.
        if course.wind.gustSigma > 0 {
            let a = dt / 2.0
            let n = Vec3(gustRNG.gaussian(), gustRNG.gaussian(), gustRNG.gaussian() * 0.3)
            gust += (-gust * a) + n * course.wind.gustSigma * (2 * a).squareRoot()
        }
        let w = wind(at: position.z)
        let air = velocity - w
        let airspeed = simd_len(air)
        let mach = airspeed / atm.speedOfSound
        let q = 0.5 * atm.density * airspeed * airspeed

        // Engines
        let thr = effectiveThrottle
        var thrust = 0.0
        if thr > 0 {
            for e in engines { thrust += e.thrust(pressure: atm.pressure, throttle: thr) }
            let burn = engines.reduce(0) { $0 + $1.mdot * thr } * dt
            propellant = max(0, propellant - burn)
        }
        let firing = thrust > 0
        if firing && !ignited {
            ignited = true
            let twr = thrust / (mass * g0)
            if twr < 1 {
                fail("fail.launch-twr", "Not enough thrust",
                     "Thrust to weight at ignition was \(fmt(twr, 2)). It must be at least 1.0. Remove mass or add thrust.",
                     value: twr, limit: 1); return
            }
        }

        // Energy
        energyWh = max(0, energyWh - electricDraw * dt / 3600)

        // Forces
        let m = mass
        let r = Self.earthR + position.z
        var accel = Vec3(0, 0, -Self.mu / (r * r))
        let nose = noseVector
        accel += nose * (thrust / m)
        if airspeed > 0.01 {
            var cda = bodyCdA(mach, firing)
            if let chute = parachute, chuteStage == 1 || chuteStage == 2 {
                let open = chuteStage == 1 ? chute.drogueOpen : chute.mainOpen
                let f = min(1, (time - chuteDeployTime) / open)
                let full = chuteStage == 1 ? chute.drogueCd * chute.drogueArea : chute.mainCd * chute.mainArea
                let prev = chuteStage == 2 ? chute.drogueCd * chute.drogueArea : 0
                cda += prev + (full - prev) * f
            }
            accel -= air / airspeed * (q * cda / m)
        }
        let nonGrav = accel - Vec3(0, 0, -Self.mu / (r * r))

        if !launched {
            if accel.z > 0 { launched = true; event("Liftoff") } else { accel = .zero; velocity = .zero }
        }

        // Attitude: rate loop (bandwidth 3 rad/s) with gimbal authority while firing or fins with q > 2 kPa,
        // plus fin weathercocking toward the relative wind.
        if launched && position.z > 5 && chuteStage == 0 {
            // Gimbal while firing, fins above 2 kPa, otherwise the probe core's cold-gas attitude control (slice simplification).
            let authority = true
            let k = min(1, 3 * dt)
            if authority { rates += (rateCommand - rates) * k } else { rates -= rates * k }
            var weather = Vec3.zero
            if hasFins && airspeed > 5 {
                let dir = air / airspeed
                let wp = asin(min(max(dir.z, -1), 1))
                let wy = atan2(dir.x, dir.y)
                let gain = 0.5 * min(1, q / 5000)
                weather.x = gain * (wp - pitch)
                weather.y = gain * wrapAngle(wy - yaw) * cos(pitch) * cos(pitch)
            }
            pitch = min(max(pitch + (rates.x + weather.x) * dt, -.pi / 2), .pi / 2)
            yaw = wrapAngle(yaw + (rates.y + weather.y) * dt)
            roll = wrapAngle(roll + rates.z * dt)
        }

        // Integrate (semi-implicit Euler)
        let prev = position
        if launched {
            velocity += accel * dt
            position += velocity * dt
        }
        tick += 1
        time = Double(tick) * dt
        if position.z > apogee { apogee = position.z }
        if launched && !reachedApogee && velocity.z < 0 && position.z > 10 { reachedApogee = true }

        checkRules(prev: prev, q: q, nonGrav: nonGrav)
    }

    private func runGuidance() {
        guidanceTicks += 1
        if let g = guidance {
            switch g.update(self, dt: 1 / Self.guidanceRate) {
            case .ok: skippedTicks = 0
            case let .fault(msg, line):
                skippedTicks += 1
                recordFault(line: line, message: msg)
                if skippedTicks >= 50 {
                    fail("fail.runtime", "Code stopped responding",
                         "50 guidance ticks in a row were skipped. Last fault: \(msg) at line \(line).",
                         value: 50, limit: 50, line: line)
                    return
                }
            }
        }
        // Sample at 50 Hz
        samples.append(FlightSample(t: time, position: position, velocity: velocity, pitch: pitch, yaw: yaw,
                                    throttle: effectiveThrottle, fuel: fuelFraction, energy: energyWh))
        // Pitch tracking RMS from rail exit to apogee.
        if case let .hop(_, _, rms) = mission.goal, rms != nil, launched, position.z > 5, !reachedApogee {
            let target = position.z < 50 ? Double.pi / 2 : 80 * Double.pi / 180
            let e = (target - pitch) * 180 / .pi
            pitchErrSq += e * e; pitchErrN += 1
        }
    }

    private func checkRules(prev: Vec3, q: Double, nonGrav: Vec3) {
        // Aero overload on fins
        if let fq = finMaxQ, q / 1000 > fq {
            fail("fail.aero", "Fin tore away",
                 "Dynamic pressure \(fmt(q / 1000, 1)) kPa was over the \(fmt(fq, 0)) kPa limit. Slow down or remove the part. Line \(lineText).",
                 value: q / 1000, limit: fq); return
        }
        // Max g
        let gLoad = simd_len(nonGrav) / g0
        if launched && gLoad > lowestMaxG {
            fail("fail.structural", "Part broke off",
                 "Acceleration \(fmt(gLoad, 1)) g was over the \(fmt(lowestMaxG, 0)) g limit. Line \(lineText).",
                 value: gLoad, limit: lowestMaxG); return
        }
        // Gates and finish
        if let g = nextGate, (prev.y - g.centre.y) * (position.y - g.centre.y) <= 0, prev.y != position.y {
            let f = (g.centre.y - prev.y) / (position.y - prev.y)
            let p = prev + (position - prev) * f
            let d = ((p.x - g.centre.x) * (p.x - g.centre.x) + (p.z - g.centre.z) * (p.z - g.centre.z)).squareRoot()
            let craftR = 0.625
            let ringDist = abs(d - (g.innerRadius + g.tubeRadius)) - g.tubeRadius
            if ringDist < craftR {
                fail("fail.collision", "Collision with \(g.id)",
                     "Impact at \(fmt(simd_len(velocity), 1)) m/s. Closest clearance before impact was \(fmt(max(0, minClearance ?? 0), 1)) m. Line \(lineText).",
                     value: simd_len(velocity), limit: 0); return
            }
            if d < g.innerRadius {
                gatesPassed += 1
                let c = g.innerRadius - d
                minClearance = min(minClearance ?? c, c)
                event("\(g.id) passed, clearance \(fmt(c, 1)) m")
            } else if position.y > g.centre.y {
                fail("fail.gate", "Missed \(g.id)",
                     "The craft crossed the \(g.id) plane \(fmt(d - g.innerRadius, 1)) m outside the ring. Line \(lineText).",
                     value: d, limit: g.innerRadius); return
            }
        }
        if let fy = course.finishY, gatesPassed == course.gates.count, prev.y < fy, position.y >= fy {
            pass(); return
        }
        // Terrain
        if launched && position.z <= 0 {
            // Touchdown speed is the descent rate; horizontal drift under canopy is absorbed by the gear/legs.
            let v = abs(velocity.z)
            position.z = 0
            if v > 6 {
                fail("fail.collision", "Collision with terrain",
                     "Impact at \(fmt(v, 1)) m/s. Line \(lineText).", value: v, limit: 6); return
            }
            landed(speed: v); return
        }
        // Corridor
        if launched {
            if course.corridor.contains(position, time: time) { corridorOut = 0 } else {
                corridorOut += 1 / Self.physicsRate
                if corridorOut > 2 {
                    fail("fail.corridor", "Left the course", "The craft was outside the corridor for 2 s. Line \(lineText).",
                         value: 2, limit: 2); return
                }
            }
        }
        if time >= Self.maxDuration {
            fail("fail.time", "Out of time", "The flight ran past \(Int(Self.maxDuration)) s.", value: time, limit: Self.maxDuration)
        }
    }

    private func landed(speed v: Double) {
        guard case let .hop(lo, hi, rms) = mission.goal else {
            fail("fail.landing", "Landed before the finish", "The craft touched down at \(fmt(v, 1)) m/s before the course was complete.",
                 value: v, limit: 0); return
        }
        if apogee < lo || apogee > hi {
            fail("fail.apogee", "Apogee out of range",
                 "Apogee was \(Int(apogee.rounded())) m. The window is \(Int(lo)) to \(Int(hi)) m. Tune the cutoff altitude.",
                 value: apogee, limit: apogee < lo ? lo : hi); return
        }
        if let zone = course.landingZone {
            let d = simd_len(Vec3(position.x - zone.centre.x, position.y - zone.centre.y, 0))
            if d > zone.radius {
                fail("fail.landing", "Landed outside the zone",
                     "Touchdown \(Int(d)) m from the zone centre. The zone radius is \(Int(zone.radius)) m.", value: d, limit: zone.radius)
                return
            }
        }
        if let rms, let got = pitchRMS, got > rms {
            fail("fail.pitch", "Pitch program not held",
                 "Pitch error RMS was \(fmt(got, 1)) deg. The limit is \(fmt(rms, 0)) deg.", value: got, limit: rms); return
        }
        pass()
    }

    public var pitchRMS: Double? { pitchErrN > 0 ? (pitchErrSq / Double(pitchErrN)).squareRoot() : nil }

    var lineText: String { guidance?.activeLine.map(String.init) ?? "-" }

    private func pass() {
        event("Mission passed")
        finish(failure: nil)
    }

    private func fail(_ key: String, _ title: String, _ body: String, value: Double, limit: Double, line: Int? = nil) {
        let f = FlightFailure(key: key, title: title, body: body, time: time, tick: tick, value: value, limit: limit,
                              line: line ?? guidance?.activeLine)
        event(title)
        finish(failure: f)
    }

    private func finish(failure: FlightFailure?) {
        finished = true
        samples.append(FlightSample(t: time, position: position, velocity: velocity, pitch: pitch, yaw: yaw,
                                    throttle: effectiveThrottle, fuel: fuelFraction, energy: energyWh))
        let fuelUsed = (craft.stats().propellantMass - propellant)
        var score = 0
        if failure == nil {
            score = 40 + Int((20 * min(1, mission.parFuel / max(fuelUsed, 1))).rounded())
            switch mission.goal {
            case .hop: score += Int((20 * max(0, 1 - abs(apogee - 1100) / 100)).rounded())
            case .gates: score += Int((20 * min(1, (minClearance ?? 0) / (mission.parClearance ?? 6))).rounded())
            }
        }
        result = FlightResult(passed: failure == nil, failure: failure, duration: time, apogee: apogee, fuelUsed: fuelUsed,
                              gatesPassed: gatesPassed, minClearance: minClearance, pitchRMSDeg: pitchRMS, score: score)
    }
}

public func wrapAngle(_ a: Double) -> Double {
    var x = a.truncatingRemainder(dividingBy: 2 * .pi)
    if x > .pi { x -= 2 * .pi } else if x < -.pi { x += 2 * .pi }
    return x
}

func fmt(_ v: Double, _ d: Int) -> String { String(format: "%.\(d)f", v) }
