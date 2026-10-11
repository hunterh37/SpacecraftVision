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
    /// Part involved, when the rule names one.
    public var part: String?
    public init(key: String, title: String, body: String, time: Double, tick: Int, value: Double, limit: Double, line: Int?,
                part: String? = nil) {
        self.key = key; self.title = title; self.body = body; self.time = time; self.tick = tick; self.value = value
        self.limit = limit; self.line = line; self.part = part
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
    public var roll: Double = 0
    /// Hottest part temperature, K.
    public var maxTemp: Double = 0
    /// Closest obstacle surface distance minus craft radius, m (nil without obstacles).
    public var clearance: Double?
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
    public var energyUsedWh: Double = 0
    public init(passed: Bool, failure: FlightFailure?, duration: Double, apogee: Double, fuelUsed: Double, gatesPassed: Int,
                minClearance: Double?, pitchRMSDeg: Double?, score: Int, energyUsedWh: Double = 0) {
        self.passed = passed; self.failure = failure; self.duration = duration; self.apogee = apogee; self.fuelUsed = fuelUsed
        self.gatesPassed = gatesPassed; self.minClearance = minClearance; self.pitchRMSDeg = pitchRMSDeg; self.score = score
        self.energyUsedWh = energyUsedWh
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

/// One craft part during flight: temperature, exposure and whether it is still attached.
public struct PartState: Sendable {
    public let def: PartDefinition
    public let instance: UUID
    public let index: Int
    /// Stack index (top 0) of the part or of its parent for radial parts.
    public let stackIndex: Int
    public let radial: Bool
    public var temperature: Double
    public var alive = true
    public var heatCapacity: Double
    /// Aero heating area times shape factor, m².
    public var heatedArea: Double
    public var radiatingArea: Double
    public var emissivity: Double
    public var ablator: Double
}

/// Deterministic headless flight: point-mass translation at 240 Hz with tracked pitch/yaw/roll attitude,
/// inverse-square gravity, US 1976 atmosphere, per-part drag, engine Isp by ambient pressure, two-stage
/// parachute, wind with shear and seeded gusts, aircraft lift with coordinated turns, lumped part heat,
/// joint loads, the energy model, obstacles and sensors with seeded noise, and the failure rules of specs/07.
public final class FlightSimulation {
    public static let physicsRate = 240.0
    public static let guidanceRate = 50.0
    public static let maxDuration = 600.0
    static let mu = 3.986e14, earthR = 6_371_000.0
    static let sigmaSB = 5.670374e-8

    public let craft: CraftDesign
    public let mission: Mission
    public let course: Course
    public let seed: UInt64
    public var guidance: FlightGuidance?
    /// Test switch: no atmosphere (vacuum Isp, no drag).
    public var vacuum = false
    /// Test switch: perfect sensors (no noise, no dropouts).
    public var perfectSensors = false

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
    /// Liquid propellant in tanks, kg.
    public private(set) var propellant: Double
    /// Solid motor propellant, kg (burns at full thrust once lit, cannot shut down).
    public private(set) var solidPropellant: Double
    public private(set) var solidsLit = false
    public let propellantCapacity: Double
    public private(set) var energyWh: Double
    public let energyCapacity: Double
    public private(set) var energyUsedWh = 0.0
    public private(set) var energyDepleted = false
    public private(set) var chuteStage = 0   // 0 packed, 1 drogue, 2 main, 3 torn
    private var chuteDeployTime = 0.0
    public private(set) var decoupled = false
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
    public private(set) var parts: [PartState] = []
    /// Last aerodynamic angle of attack, rad (aircraft).
    public private(set) var alpha = 0.0
    public private(set) var dynamicPressure = 0.0
    public private(set) var lastClearance: Double?
    public var random: SplitMix64
    private var gustRNG: SplitMix64
    private var sensorRNG: SplitMix64
    private var gust = Vec3.zero
    private var corridorOut = 0.0
    private var skippedTicks = 0
    private var guidanceTicks = 0
    private var pitchErrSq = 0.0, pitchErrN = 0
    private var reachedApogee = false
    private var setupDone = false
    private var lastNonGrav = Vec3.zero

    // Craft constants
    var dryMass: Double
    var engines: [EngineSpec]
    var solidEngines: [EngineSpec]
    let propEngine: Bool
    var hasFins: Bool
    let parachute: ParachuteSpec?
    var electricDraw: Double
    var bodyCdA: (_ mach: Double, _ firing: Bool) -> Double
    let lowestMaxG: Double
    /// Exposed aero parts' lowest max q, kPa, and the part name.
    var aeroMaxQ: (kPa: Double, name: String)?
    public private(set) var partIds: Set<String>
    public let isAircraft: Bool
    /// Wing planform area, m², span, m, aspect ratio.
    public let wingArea: Double
    public let wingSpan: Double
    let aspectRatio: Double
    let packCount: Int
    /// Bounding radius used for obstacle contact, m.
    public let craftRadius: Double
    let sunElevation: Double
    let hasIMU: Bool

    public init(craft: CraftDesign, mission: Mission, seed: UInt64 = 1) {
        self.craft = craft; self.mission = mission; self.course = mission.course; self.seed = seed
        random = SplitMix64(seed: seed)
        gustRNG = SplitMix64(seed: course.wind.seed &+ seed)
        sensorRNG = SplitMix64(seed: seed &* 0x5851_F42D_4C95_7F2D &+ 11)
        let expanded = craft.expandedParts
        var dry = craft.payloadMass, liquid = 0.0, solid = 0.0, liquidCap = 0.0
        for (d, inst, _) in expanded {
            dry += d.dryMass
            if d.engine?.solid == true { solid += d.propellantMass } else {
                liquid += d.propellantMass * inst.fuelLoad; liquidCap += d.propellantMass
            }
        }
        dryMass = dry
        propellant = liquid; solidPropellant = solid; propellantCapacity = liquidCap
        energyWh = expanded.reduce(0) { $0 + ($1.def.batteryWh ?? 0) }; energyCapacity = energyWh
        engines = expanded.compactMap { $0.def.realityHDId == "engine-prop" || $0.def.engine?.solid == true ? nil : $0.def.engine }
        solidEngines = expanded.compactMap { $0.def.engine?.solid == true ? $0.def.engine : nil }
        propEngine = expanded.contains { $0.def.realityHDId == "engine-prop" }
        hasFins = expanded.contains { $0.def.realityHDId == "fin-trapezoid" }
        parachute = expanded.first { $0.def.parachute != nil }?.def.parachute
        electricDraw = expanded.reduce(0) { $0 + $1.def.electricDraw }
        lowestMaxG = expanded.map(\.def.maxG).min() ?? 50
        partIds = Set(expanded.map(\.def.realityHDId))
        hasIMU = partIds.contains("imu") || partIds.contains("command-pod")
        let wings = expanded.filter { $0.def.realityHDId == "wing-section" }
        wingArea = wings.reduce(0) { $0 + $1.def.dragArea }
        let fuselage = craft.stack.map(\.definition.diameter).max() ?? 1.25
        wingSpan = wings.isEmpty ? 0 : wings.reduce(0) { $0 + $1.def.diameter } * (3.9 / 4.04) + fuselage
        aspectRatio = wingArea > 0 ? wingSpan * wingSpan / wingArea : 0
        isAircraft = mission.course.start.isAir && wingArea > 0
        packCount = expanded.filter { $0.def.realityHDId == "battery-pack" }.count
        craftRadius = isAircraft ? wingSpan / 2 : max(0.625, fuselage / 2)
        switch course.timeOfDay {
        case .morning: sunElevation = 25 * .pi / 180
        case .afternoon: sunElevation = 50 * .pi / 180
        case .golden: sunElevation = 8 * .pi / 180
        }
        bodyCdA = { _, _ in 0 }
        rebuildDrag()
        aeroMaxQ = Self.exposedMaxQ(expanded.map(\.def))
        // Part states for heat and loads.
        let ambient = course.timeOfDay.ambientK
        let stackIndex: [UUID: Int] = Dictionary(uniqueKeysWithValues: craft.stack.enumerated().map { ($1.id, $0) })
        for (i, (d, inst, _)) in expanded.enumerated() {
            let radial = d.mount == .radial
            let si = radial ? stackIndex[inst.parentId ?? UUID()] ?? 0 : stackIndex[inst.id] ?? 0
            let cp = Self.heatCapacity(d.material)
            let wetted = radial ? max(d.dragArea * 2, 0.02) : Double.pi * d.diameter * d.length
            var heated = 0.0
            if radial { heated = ["fin-trapezoid", "wing-section", "elevon"].contains(d.realityHDId) ? d.dragArea : d.dragArea * 0.5 }
            else if si == 0 { heated = d.dragArea } else { heated = 0.5 * wetted * 0.05 }
            let em = d.realityHDId == "heat-shield" ? 0.9 : (d.realityHDId == "probe-core" ? 0.05 : 0.8)
            parts.append(PartState(def: d, instance: inst.id, index: i, stackIndex: si, radial: radial, temperature: ambient,
                                   heatCapacity: max(1, d.dryMass + d.propellantMass * (d.engine?.solid == true ? 1 : inst.fuelLoad)) * cp,
                                   heatedArea: heated, radiatingArea: wetted, emissivity: em,
                                   ablator: d.realityHDId == "heat-shield" ? 40 : 0))
        }
        // Start state.
        if case let .air(alt, speed, heading) = course.start {
            position = Vec3(0, 0, alt)
            velocity = Vec3(sin(heading) * speed, cos(heading) * speed, 0)
            yaw = heading
            pitch = isAircraft ? trimAlpha(speed: speed, altitude: alt) : 0
            throttleCommand = 0.5
            launched = true; ignited = true
        }
    }

    static func heatCapacity(_ material: String) -> Double {
        let m = material.lowercased()
        if m.contains("li-ion") { return 1000 }
        if m.contains("electronics") { return 800 }
        if m.contains("titanium") { return 520 }
        if m.contains("steel") { return 500 }
        if m.contains("composite") || m.contains("nylon") { return 1100 }
        return 900
    }

    static func exposedMaxQ(_ defs: [PartDefinition]) -> (Double, String)? {
        let aero: Set<String> = ["fin-trapezoid", "wing-section", "elevon", "solar-panel", "landing-gear"]
        return defs.filter { aero.contains($0.realityHDId) }.map { ($0.maxQkPa, $0.displayName) }.min { $0.0 < $1.0 }
    }

    /// Frontal: top stack part; stacked parts below: skin friction; annulus steps Cd 0.8; radial parts own CdA.
    private func rebuildDrag() {
        let alive = Set(parts.isEmpty ? craft.expandedParts.map(\.inst.id) : parts.filter(\.alive).map(\.instance))
        let stack = craft.stack.filter { alive.contains($0.id) }.map(\.definition)
        // imu, battery and parachute pack mount inside the probe-core ring (specs/14 drag notes): no drag.
        let inner: Set<String> = ["imu", "battery-pack", "parachute"]
        let radial = craft.expandedParts.filter { $0.def.mount == .radial && !inner.contains($0.def.realityHDId) && alive.contains($0.inst.id) }
            .map(\.def)
        let aircraft = isAircraft
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
            // Aircraft wings carry their profile drag here; induced drag is added with lift.
            for r in radial { cda += (aircraft && r.realityHDId == "wing-section" ? r.cdSubsonic : r.cd(mach: mach)) * r.dragArea }
            return cda
        }
    }

    // MARK: Read-outs used by the craft API

    public var mass: Double { dryMass + propellant + solidPropellant }
    public var altitude: Double { position.z }
    public var fuelFraction: Double { propellantCapacity > 0 ? propellant / propellantCapacity : 0 }
    public var energyFraction: Double { energyCapacity > 0 ? energyWh / energyCapacity : 0 }
    public var noseVector: Vec3 { Vec3(cos(pitch) * sin(yaw), cos(pitch) * cos(yaw), sin(pitch)) }
    public var effectiveThrottle: Double {
        if propEngine { return energyDepleted ? 0 : min(throttleCommand, propThrottleCap) }
        guard throttleCommand > 0, propellant > 0 else { return 0 }
        return min(1, max(throttleCommand, engines.map(\.throttleMin).max() ?? 0))
    }
    /// Pack limit caps the electric propeller (specs/14: 25 kW per pack, not a failure).
    var propThrottleCap: Double {
        guard packCount > 0 else { return 1 }
        return min(1, max(0, Double(packCount) * 25_000 - electricDraw) / 87_000)
    }
    public var thrustMax: Double {
        let p = Atmosphere.at(altitude: position.z).pressure
        var t = propellant > 0 ? engines.reduce(0) { $0 + $1.thrust(pressure: p, throttle: 1) } : 0
        if solidPropellant > 0 { t += solidEngines.reduce(0) { $0 + $1.thrust(pressure: p, throttle: 1) } }
        if propEngine && !energyDepleted { t += propThrust(throttle: propThrottleCap, airspeed: simd_len(velocity)) }
        return t
    }
    public var nextGate: Gate? { gatesPassed < course.gates.count ? course.gates[gatesPassed] : nil }
    public var guidanceTime: Double { max(0, time - 0) }
    public var energyUsed: Double { energyUsedWh }
    public var maxPartTemperature: Double { parts.filter(\.alive).map(\.temperature).max() ?? course.timeOfDay.ambientK }

    /// Temperature of the hottest part with this id (or the hottest part overall for nil), K.
    public func temperature(of id: String?) -> Double {
        guard let id else { return maxPartTemperature }
        return parts.filter { $0.def.realityHDId == id }.map(\.temperature).max() ?? course.timeOfDay.ambientK
    }

    /// (bearing relative to yaw, elevation, distance) toward a point.
    public func relative(to p: Vec3) -> (Double, Double, Double) {
        let d = p - position
        let h = (d.x * d.x + d.y * d.y).squareRoot()
        let bearing = wrapAngle(atan2(d.x, d.y) - yaw)
        return (bearing, atan2(d.z, h), simd_len(d))
    }

    func propThrust(throttle: Double, airspeed: Double) -> Double {
        let p = throttle * 80_000
        return min(2_800, 0.80 * p / max(airspeed, 1))
    }

    // MARK: Commands

    public func setThrottle(_ x: Double) { throttleCommand = min(max(x, 0), 1) }
    public func setPitchRate(_ r: Double) { let l = isAircraft ? 0.6 : 0.5; rateCommand.x = min(max(r, -l), l) }
    public func setYawRate(_ r: Double) { let l = isAircraft ? 0.25 : 0.5; rateCommand.y = min(max(r, -l), l) }
    public func setRollRate(_ r: Double) { let l = isAircraft ? 1.5 : 1.0; rateCommand.z = min(max(r, -l), l) }
    public func log(_ s: String) { lastLog = s }
    public func plot(_ name: String, _ v: Double) {
        userSeries[name, default: []].append((time, v))
    }
    public func recordFault(line: Int, message: String) {
        if faultMessages.count < 200 { faultMessages.append((line, message)) }
    }

    /// Fire the next stage item: decoupler, then parachute drogue, then main.
    public func stage() {
        if !decoupled, let di = craft.stack.firstIndex(where: { $0.partId == "decoupler" }) {
            decouple(at: di); return
        }
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

    /// Springs separate everything below the decoupler: their mass, engines and tank propellant leave.
    private func decouple(at di: Int) {
        decoupled = true
        let below = Set(craft.stack[(di + 1)...].map(\.id))
        var lostProp = 0.0, lostCap = 0.0
        for i in parts.indices where parts[i].alive && parts[i].stackIndex > di {
            parts[i].alive = false
            let d = parts[i].def
            dryMass -= d.dryMass
            if d.engine?.solid != true, d.propellantMass > 0 {
                let inst = craft.expandedParts[parts[i].index].inst
                lostCap += d.propellantMass; lostProp += d.propellantMass * inst.fuelLoad
            }
        }
        // Propellant is pooled; the lower tanks' share of what is left goes with them.
        if propellantCapacity > 0 { propellant -= propellant * min(1, lostCap / propellantCapacity) }
        _ = lostProp; _ = below
        refreshAfterPartLoss()
        event("Decoupler fired")
    }

    private func refreshAfterPartLoss() {
        let alive = parts.filter(\.alive)
        engines = alive.compactMap { $0.def.realityHDId == "engine-prop" || $0.def.engine?.solid == true ? nil : $0.def.engine }
        solidEngines = alive.compactMap { $0.def.engine?.solid == true ? $0.def.engine : nil }
        if solidEngines.isEmpty { solidPropellant = 0 }
        hasFins = alive.contains { $0.def.realityHDId == "fin-trapezoid" }
        electricDraw = alive.reduce(0) { $0 + $1.def.electricDraw }
        partIds = Set(alive.map(\.def.realityHDId))
        aeroMaxQ = Self.exposedMaxQ(alive.map(\.def))
        rebuildDrag()
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

    /// Pitch giving level flight at this speed (CL for weight), used for the air start.
    func trimAlpha(speed: Double, altitude: Double) -> Double {
        let rho = Atmosphere.at(altitude: altitude).density
        let q = 0.5 * rho * speed * speed
        let cl = mass * g0 / max(q * wingArea, 1)
        return (cl - Self.cl0) / liftSlope
    }

    static let cl0 = 0.25            // NACA 2412 at zero incidence
    static let clMax = 1.3
    static let stallAlpha = 15 * Double.pi / 180
    var liftSlope: Double { 2 * .pi / (1 + 2 / max(aspectRatio, 1)) }

    func liftCoefficient(_ a: Double) -> Double {
        if abs(a) > Self.stallAlpha { return 0.7 * (a > 0 ? 1 : -1) }
        return min(max(Self.cl0 + liftSlope * a, -Self.clMax), Self.clMax)
    }

    public func step() {
        guard !finished else { return }
        let dt = 1 / Self.physicsRate
        if !setupDone {
            setupDone = true
            if let g = guidance, case let .fault(msg, line) = g.setup(self) { recordFault(line: line, message: msg) }
        }
        // Guidance at 50 Hz: tick k fires when floor(k * 50 / 240) advances.
        let guidanceTick = tick == 0 || (tick * 50) / 240 != ((tick - 1) * 50) / 240
        if guidanceTick {
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
        dynamicPressure = q

        // Engines
        let thr = effectiveThrottle
        var thrust = 0.0
        var jetPower = 0.0
        if propEngine {
            thrust += propThrust(throttle: thr, airspeed: airspeed)
        } else if thr > 0 {
            for e in engines {
                let f = e.thrust(pressure: atm.pressure, throttle: thr)
                thrust += f; jetPower += e.heatFraction * 0.5 * f * e.isp(pressure: atm.pressure) * g0
            }
            let burn = engines.reduce(0) { $0 + $1.mdot * thr } * dt
            propellant = max(0, propellant - burn)
        }
        if !solidsLit && throttleCommand > 0 && !solidEngines.isEmpty && solidPropellant > 0 { solidsLit = true; event("Solid motors lit") }
        if solidsLit && solidPropellant > 0 {
            for e in solidEngines {
                let f = e.thrust(pressure: atm.pressure, throttle: 1)
                thrust += f; jetPower += e.heatFraction * 0.5 * f * e.isp(pressure: atm.pressure) * g0
            }
            solidPropellant = max(0, solidPropellant - solidEngines.reduce(0) { $0 + $1.mdot } * dt)
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

        // Energy (specs/07 energy model)
        var draw = electricDraw
        if !isAircraft && firing && simd_len(Vec3(rateCommand.x, rateCommand.y, 0)) > 1e-4 && partIds.contains("engine-liquid-small") { draw += 60 }
        if isAircraft && abs(rateCommand.x) + abs(rateCommand.z) > 1e-4 && partIds.contains("elevon") { draw += 20 }
        if propEngine { draw += thr * 87_000 }
        var solar = 0.0
        if partIds.contains("solar-panel") && sunElevation > 0 {
            let panels = Double(parts.filter { $0.alive && $0.def.realityHDId == "solar-panel" }.count)
            solar = panels * 210 * sin(sunElevation)
        }
        let net = draw - solar
        if !energyDepleted {
            energyWh = min(energyCapacity, energyWh - net * dt / 3600)
            energyUsedWh += max(0, net) * dt / 3600
            if energyWh <= 0 && draw > 0 {
                energyWh = 0; energyDepleted = true
                event("Battery empty: sensors, gimbal and elevons stopped")
            }
        } else if net < 0 {
            energyWh = min(energyCapacity, energyWh - net * dt / 3600)
            if energyWh > 1 { energyDepleted = false }
        }

        // Forces
        let m = mass
        let r = Self.earthR + position.z
        let gravity = Vec3(0, 0, -Self.mu / (r * r))
        var accel = gravity
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
            let u = air / airspeed
            if isAircraft && wingArea > 0 {
                let gamma = asin(min(max(u.z, -1), 1))
                alpha = pitch - gamma
                let cl = liftCoefficient(alpha)
                // Induced drag, Oswald 0.8.
                cda += cl * cl / (Double.pi * 0.8 * max(aspectRatio, 1)) * wingArea
                var up0 = Vec3(0, 0, 1) - u * u.z
                let ul = simd_len(up0)
                up0 = ul > 1e-6 ? up0 / ul : Vec3(0, 1, 0)
                let side = Vec3(u.y * up0.z - u.z * up0.y, u.z * up0.x - u.x * up0.z, u.x * up0.y - u.y * up0.x)
                let liftDir = up0 * cos(roll) + side * sin(roll)
                accel += liftDir * (q * wingArea * cl / m)
            }
            accel -= u * (q * cda / m)
        }
        let nonGrav = accel - gravity
        lastNonGrav = nonGrav

        if !launched {
            if accel.z > 0 { launched = true; event("Liftoff") } else { accel = .zero; velocity = .zero }
        }

        // Attitude
        if isAircraft {
            // Rate loop on pitch; set_yaw is a heading rate flown as a coordinated turn with bank atan(v r / g).
            let k = min(1, 3 * dt)
            let authority = !energyDepleted
            let pitchCmd = authority ? rateCommand.x : 0
            rates.x += (pitchCmd - rates.x) * k
            pitch = min(max(pitch + rates.x * dt, -.pi / 2), .pi / 2)
            let bankTarget = authority ? atan(airspeed * rateCommand.y / g0) : roll
            let bankLimit = 45 * Double.pi / 180
            var target = min(max(bankTarget, -bankLimit), bankLimit)
            if authority && abs(rateCommand.z) > 1e-6 { target = min(max(roll + rateCommand.z * 0.2, -1.2), 1.2) }
            let maxRoll = 1.5 * dt
            roll += min(max(target - roll, -maxRoll), maxRoll)
            // Yaw damper: the nose follows the air-relative track.
            if airspeed > 1 { yaw = atan2(air.x, air.y) }
        } else if launched && position.z > 5 && chuteStage == 0 {
            // Gimbal while firing, fins above 2 kPa, otherwise the probe core's cold-gas attitude control (slice simplification).
            let authority = !energyDepleted
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

        if guidanceTick { updateHeat(dt: 1 / Self.guidanceRate, q: q, airspeed: airspeed, atm: atm, jetPower: jetPower, draw: draw) }
        if finished { return }
        checkRules(prev: prev, q: q, nonGrav: nonGrav)
    }

    // MARK: Heat (specs/07 heat model, run at 50 Hz)

    private func updateHeat(dt: Double, q: Double, airspeed: Double, atm: Atmosphere.Sample, jetPower: Double, draw: Double) {
        let tAmb = atm.temperature
        let cpAir = 1005.0, ch = 2.5e-3
        let tAw = tAmb + 0.89 * airspeed * airspeed / (2 * cpAir)
        let engineIdx = parts.indices.filter { parts[$0].alive && parts[$0].def.engine != nil && parts[$0].def.realityHDId != "engine-prop" }
        let packIdx = parts.indices.filter { parts[$0].alive && parts[$0].def.realityHDId == "battery-pack" }
        var flux = [Double](repeating: 0, count: parts.count)
        for i in parts.indices where parts[i].alive {
            let p = parts[i]
            if p.heatedArea > 0 && atm.density > 0 {
                flux[i] += ch * atm.density * airspeed * cpAir * p.heatedArea * (tAw - p.temperature)
            }
            flux[i] -= p.emissivity * Self.sigmaSB * p.radiatingArea * (pow(p.temperature, 4) - pow(tAmb, 4))
        }
        if !engineIdx.isEmpty && jetPower > 0 { for i in engineIdx { flux[i] += jetPower / Double(engineIdx.count) } }
        if !packIdx.isEmpty { for i in packIdx { flux[i] += 0.03 * draw / Double(packIdx.count) } }
        // Conduction 5 W/K between stack neighbours and from radial parts to their parent.
        let stackOf: [Int: Int] = Dictionary(parts.indices.filter { !parts[$0].radial }.map { (parts[$0].stackIndex, $0) }) { a, _ in a }
        for i in parts.indices where parts[i].alive {
            let neighbour: Int?
            if parts[i].radial { neighbour = stackOf[parts[i].stackIndex] } else { neighbour = stackOf[parts[i].stackIndex + 1] }
            if let j = neighbour, j != i, parts[j].alive {
                let f = 5 * (parts[j].temperature - parts[i].temperature)
                flux[i] += f; flux[j] -= f
            }
        }
        for i in parts.indices where parts[i].alive {
            var p = parts[i]
            // Heat shield ablation: 1 kg per 40 MJ absorbed above 1,000 K.
            if p.ablator > 0 && p.temperature > 1000 && flux[i] > 0 {
                let absorbed = flux[i] * dt
                p.ablator = max(0, p.ablator - absorbed / 40e6)
                flux[i] *= 0.2
            }
            p.temperature += flux[i] * dt / p.heatCapacity
            parts[i] = p
            let limit = p.def.realityHDId == "heat-shield" && p.ablator <= 0 ? 600 : p.def.maxTemp
            if p.temperature > limit {
                parts[i].alive = false
                if p.def.category == .command {
                    fail("fail.heat", "Overheated",
                         "\(p.def.displayName) reached \(Int(p.temperature)) K. Its limit is \(Int(limit)) K. Line \(lineText).",
                         value: p.temperature, limit: limit, part: p.def.realityHDId); return
                }
                event("\(p.def.displayName) overheated at \(Int(p.temperature)) K")
                refreshAfterPartLoss()
            }
        }
    }

    // MARK: Sensors (specs/14 sensor table; noise seeded and sampled per guidance tick)

    private var noiseTick = -1
    private var noise = (pos: Vec3.zero, vel: Vec3.zero, att: Vec3.zero)
    private var heldPosition = Vec3.zero
    private var heldPositionTick = -100

    private func refreshNoise() {
        guard noiseTick != guidanceTicks else { return }
        noiseTick = guidanceTicks
        if perfectSensors { noise = (.zero, .zero, .zero); heldPosition = position; return }
        let g = { [self] in sensorRNG.gaussian() }
        if hasIMU {
            noise.pos = Vec3(g() * 0.5, g() * 0.5, g() * 1.0)
            noise.vel = Vec3(g(), g(), g()) * 0.05
            noise.att = Vec3(g(), g(), g()) * (0.05 * .pi / 180)
            heldPosition = position + noise.pos
        } else {
            noise.vel = Vec3(g(), g(), g()) * 0.2
            noise.att = Vec3(g(), g(), g()) * (1.0 * .pi / 180)
            // Tier 0 position updates at 5 Hz.
            if guidanceTicks - heldPositionTick >= 10 {
                heldPositionTick = guidanceTicks
                heldPosition = position + Vec3(g() * 2, g() * 2, g() * 3)
            }
        }
    }

    public var sensedPosition: Vec3 { refreshNoise(); return hasIMU || perfectSensors ? position + noise.pos : heldPosition }
    public var sensedVelocity: Vec3 { refreshNoise(); return velocity + noise.vel }
    public var sensedAttitude: Vec3 { refreshNoise(); return Vec3(pitch, yaw, roll) + noise.att }

    /// Lidar range at an angle (degrees, relative to heading, positive right) in the stabilized horizontal plane; -1 for no return.
    public func lidar(angleDeg: Double) -> Double {
        guard partIds.contains("lidar-sensor"), !energyDepleted else { return -1 }
        let a = yaw + angleDeg * .pi / 180
        var dir = Vec3(sin(a), cos(a), 0)
        // The head holds level within 30 deg of body tilt, then tilts with the body.
        let tilt = isAircraft ? abs(roll) : abs(.pi / 2 - pitch) * 0
        if tilt > 30 * Double.pi / 180 && isAircraft {
            let excess = (tilt - 30 * Double.pi / 180) * (roll > 0 ? 1 : -1)
            let side = Vec3(cos(yaw), -sin(yaw), 0)
            let s = (dir.x * side.x + dir.y * side.y)
            dir = simd_normalize_d(dir + Vec3(0, 0, -s * sin(excess)))
        }
        guard let d = course.raycast(from: position, dir: dir, maxRange: 120, at: time, includeGates: true), d >= 0.5 else { return -1 }
        if perfectSensors { return d }
        if sensorRNG.unit() < 0.01 { return -1 }
        return d + sensorRNG.gaussian() * 0.03
    }

    /// 36 rays from -180 to 170 degrees.
    public func lidarScan() -> [(Double, Double)] {
        guard partIds.contains("lidar-sensor") else { return [] }
        return stride(from: -180, to: 180, by: 10).map { a in (Double(a), lidar(angleDeg: Double(a))) }
    }

    /// Nose-axis frame: forward, right, up.
    var bodyFrame: (f: Vec3, r: Vec3, u: Vec3) {
        let f = noseVector
        let r = Vec3(cos(yaw), -sin(yaw), 0)
        let u = Vec3(r.y * f.z - r.z * f.y, r.z * f.x - r.x * f.z, r.x * f.y - r.y * f.x)
        return (f, r, u)
    }

    /// Radar contacts: (bearing, elevation, range, closing speed) about the nose axis, ±60 deg az, ±40 deg el.
    public func radar() -> [(Double, Double, Double, Double)] {
        guard partIds.contains("radar-sensor"), !energyDepleted else { return [] }
        let (f, r, u) = bodyFrame
        var out: [(Double, Double, Double, Double)] = []
        for o in course.obstacles where o.moving {
            let p = o.position(at: time), d = p - position
            let dist = simd_len(d)
            let range = 2000 * pow(max(o.rcs, 0.01), 0.25)
            guard dist < range, dist > 0 else { continue }
            let df = simd_dot_d(d, f), dr = simd_dot_d(d, r), du = simd_dot_d(d, u)
            let b = atan2(dr, df), e = atan2(du, (df * df + dr * dr).squareRoot())
            guard abs(b) <= 60 * .pi / 180, abs(e) <= 40 * .pi / 180 else { continue }
            let closing = -simd_dot_d(d / dist, o.velocity(at: time) - velocity)
            let n = perfectSensors ? Vec3.zero : Vec3(sensorRNG.gaussian(), sensorRNG.gaussian(), sensorRNG.gaussian())
            out.append((b + n.x * 0.5 * .pi / 180, e + n.y * 0.5 * .pi / 180, dist - o.radius + n.z, closing))
        }
        return out
    }

    /// Radar tracks of moving obstacles: (relative position, relative velocity, radius), course frame.
    public func radarTracks() -> [(Vec3, Vec3, Double)] {
        guard partIds.contains("radar-sensor"), !energyDepleted else { return [] }
        var out: [(Vec3, Vec3, Double)] = []
        for o in course.obstacles where o.moving {
            let d = o.position(at: time) - position
            let range = 2000 * pow(max(o.rcs, 0.01), 0.25)
            guard simd_len(d) < range else { continue }
            var rv = o.velocity(at: time) - velocity
            var rp = d
            if !perfectSensors {
                rp += Vec3(sensorRNG.gaussian(), sensorRNG.gaussian(), sensorRNG.gaussian()) * 0.6
                rv += Vec3(sensorRNG.gaussian(), sensorRNG.gaussian(), sensorRNG.gaussian()) * 0.5
            }
            out.append((rp, rv, o.radius))
        }
        return out
    }

    /// Camera detections: (id, bearing, elevation, angular size), 90 x 60 deg about the nose, 400 m, 0.15 deg minimum.
    public func cameraObjects() -> [(String, Double, Double, Double)] {
        guard partIds.contains("camera-sensor"), !energyDepleted else { return [] }
        let (f, r, u) = bodyFrame
        var out: [(String, Double, Double, Double)] = []
        var targets: [(String, Vec3, Double)] = course.obstacles.map { ($0.id, $0.kind == .wall || $0.kind == .pylon || $0.kind == .pillar
            ? Vec3($0.centre.x, $0.centre.y, min(max(position.z, 0), $0.kind == .wall ? $0.centre.z + $0.height / 2 : $0.height))
            : $0.position(at: time), $0.kind == .wall ? $0.length / 2 : $0.radius) }
        targets += course.gates.map { ($0.id, $0.centre, $0.innerRadius + 2 * $0.tubeRadius) }
        for (id, p, size) in targets {
            let d = p - position
            let dist = simd_len(d)
            guard dist > 0, dist < 400 else { continue }
            let df = simd_dot_d(d, f), dr = simd_dot_d(d, r), du = simd_dot_d(d, u)
            let b = atan2(dr, df), e = atan2(du, (df * df + dr * dr).squareRoot())
            let ang = 2 * atan(size / dist)
            guard abs(b) <= 45 * .pi / 180, abs(e) <= 30 * .pi / 180, ang >= 0.15 * .pi / 180 else { continue }
            let nb = perfectSensors ? 0 : sensorRNG.gaussian() * 0.2 * .pi / 180
            let ns = perfectSensors ? 0 : sensorRNG.gaussian() * 0.05
            out.append((id, b + nb, e, ang * (1 + ns)))
        }
        return out
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
        // Clearance to obstacles (CoM to surface minus craft radius), sampled at 50 Hz.
        if !course.obstacles.isEmpty || course.canyon != nil, let n = course.nearestObstacle(position, at: time) {
            let c = n.distance - craftRadius
            lastClearance = c
            if launched { minClearance = min(minClearance ?? c, c) }
        }
        // Sample at 50 Hz
        samples.append(sample())
        // Pitch tracking RMS from rail exit to apogee.
        if case let .hop(_, _, rms) = mission.goal, rms != nil, launched, position.z > 5, !reachedApogee {
            let target = position.z < 50 ? Double.pi / 2 : 80 * Double.pi / 180
            let e = (target - pitch) * 180 / .pi
            pitchErrSq += e * e; pitchErrN += 1
        }
    }

    private func sample() -> FlightSample {
        FlightSample(t: time, position: position, velocity: velocity, pitch: pitch, yaw: yaw, throttle: effectiveThrottle,
                     fuel: fuelFraction, energy: energyWh, roll: roll, maxTemp: maxPartTemperature, clearance: lastClearance)
    }

    private func checkRules(prev: Vec3, q: Double, nonGrav: Vec3) {
        // Aero overload on exposed parts
        if let a = aeroMaxQ, q / 1000 > a.kPa {
            fail("fail.aero", "\(a.name) tore away",
                 "Dynamic pressure \(fmt(q / 1000, 1)) kPa was over the \(fmt(a.kPa, 0)) kPa limit. Slow down or remove the part. Line \(lineText).",
                 value: q / 1000, limit: a.kPa); return
        }
        // Max g
        let gLoad = simd_len(nonGrav) / g0
        if launched && gLoad > lowestMaxG {
            fail("fail.structural", "Part broke off",
                 "Acceleration \(fmt(gLoad, 1)) g was over the \(fmt(lowestMaxG, 0)) g limit. Line \(lineText).",
                 value: gLoad, limit: lowestMaxG); return
        }
        // Joint loads: axial and lateral force at each stack joint from the mass above it.
        if launched && !isAircraft { if checkJoints(nonGrav) { return } }
        // Obstacles
        if launched, !course.obstacles.isEmpty || course.canyon != nil, let n = course.nearestObstacle(position, at: time),
           n.distance < craftRadius {
            fail("fail.collision", "Collision with \(n.id)",
                 "Impact at \(fmt(simd_len(velocity), 1)) m/s. Closest clearance before impact was \(fmt(max(0, minClearance ?? 0), 1)) m. Line \(lineText).",
                 value: simd_len(velocity), limit: 0); return
        }
        // Gates and finish
        if let g = nextGate, (prev.y - g.centre.y) * (position.y - g.centre.y) <= 0, prev.y != position.y {
            let f = (g.centre.y - prev.y) / (position.y - prev.y)
            let p = prev + (position - prev) * f
            let d = ((p.x - g.centre.x) * (p.x - g.centre.x) + (p.z - g.centre.z) * (p.z - g.centre.z)).squareRoot()
            let ringDist = abs(d - (g.innerRadius + g.tubeRadius)) - g.tubeRadius
            let contactR = isAircraft ? min(craftRadius, 2.0) : craftRadius
            if ringDist < contactR {
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
        if let fz = course.finishZ, prev.z < fz, position.z >= fz {
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

    /// True when a joint broke and ended the flight.
    private func checkJoints(_ nonGrav: Vec3) -> Bool {
        let f = noseVector
        let axial = simd_dot_d(nonGrav, f)
        let lateral = simd_len(nonGrav - f * axial)
        let alive = parts.filter(\.alive)
        let stackCount = craft.stack.count
        guard stackCount > 1 else { return false }
        var massAbove = craft.payloadMass
        for si in 0..<(stackCount - 1) {
            for p in alive where p.stackIndex == si {
                massAbove += p.def.dryMass
                if p.def.propellantMass > 0, propellantCapacity > 0, p.def.engine?.solid != true {
                    massAbove += p.def.propellantMass / propellantCapacity * propellant
                }
                if p.def.engine?.solid == true, !solidEngines.isEmpty {
                    massAbove += solidPropellant / Double(solidEngines.count)
                }
            }
            let upper = craft.stack[si].definition, lower = craft.stack[si + 1].definition
            let axialLimit = min(upper.jointAxialKN, lower.jointAxialKN) * 1000
            let lateralLimit = min(upper.jointLateralKN, lower.jointLateralKN) * 1000
            let fa = massAbove * abs(axial), fl = massAbove * lateral
            if fa > axialLimit || fl > lateralLimit {
                let over = fa > axialLimit
                fail("fail.structural", "Joint broke",
                     "The \(upper.displayName) to \(lower.displayName) joint carried \(fmt((over ? fa : fl) / 1000, 1)) kN \(over ? "axial" : "lateral"). The limit is \(fmt((over ? axialLimit : lateralLimit) / 1000, 0)) kN. Line \(lineText).",
                     value: (over ? fa : fl) / 1000, limit: (over ? axialLimit : lateralLimit) / 1000, part: lower.realityHDId)
                return true
            }
        }
        // Radial parts break off on their own joint limit.
        var lost = false
        for i in parts.indices where parts[i].alive && parts[i].radial {
            let d = parts[i].def
            let fa = d.dryMass * abs(axial), fl = d.dryMass * lateral
            if fa > d.jointAxialKN * 1000 || fl > d.jointLateralKN * 1000 {
                parts[i].alive = false; lost = true
                event("\(d.displayName) broke off")
            }
        }
        if lost { refreshAfterPartLoss() }
        return false
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

    private func fail(_ key: String, _ title: String, _ body: String, value: Double, limit: Double, line: Int? = nil,
                      part: String? = nil) {
        var f = FlightFailure(key: key, title: title, body: body, time: time, tick: tick, value: value, limit: limit,
                              line: line ?? guidance?.activeLine, part: part)
        // An empty battery is the recorded cause when the flight later ends without a Pass (specs/07).
        if energyDepleted && key != "fail.runtime" {
            f = FlightFailure(key: "fail.energy", title: "Battery empty",
                              body: "The battery ran flat with electric parts drawing; sensors, gimbal and elevons stopped. Then: \(title.lowercased()).",
                              time: time, tick: tick, value: 0, limit: 0, line: f.line, part: nil)
        }
        event(title)
        finish(failure: f)
    }

    private func finish(failure: FlightFailure?) {
        finished = true
        samples.append(sample())
        let fuelUsed = craft.stats().propellantMass - propellant - solidPropellant
        var score = 0
        if failure == nil {
            let used = isAircraft || propEngine ? energyUsedWh : fuelUsed
            score = 40 + Int((20 * min(1, mission.parFuel / max(used, 1))).rounded())
            switch mission.goal {
            case .hop: score += Int((20 * max(0, 1 - abs(apogee - 1100) / 100)).rounded())
            case .gates, .climb: score += Int((20 * min(1, max(0, minClearance ?? 0) / (mission.parClearance ?? 6))).rounded())
            case .capstone:
                // Lesson 10: 50% energy vs par (0.35 Wh per metre), 50% time vs par (length / 32 m/s).
                let length = course.finishY ?? course.goal.y
                let eScore = min(1, 0.35 * length / max(energyUsedWh, 1))
                let tScore = min(1, (length / 32) / max(time, 1))
                score = Int((100 * (0.5 * eScore + 0.5 * tScore)).rounded())
            }
        }
        result = FlightResult(passed: failure == nil, failure: failure, duration: time, apogee: apogee, fuelUsed: fuelUsed,
                              gatesPassed: gatesPassed, minClearance: minClearance, pitchRMSDeg: pitchRMS, score: score,
                              energyUsedWh: energyUsedWh)
    }
}

public func wrapAngle(_ a: Double) -> Double {
    var x = a.truncatingRemainder(dividingBy: 2 * .pi)
    if x > .pi { x -= 2 * .pi } else if x < -.pi { x += 2 * .pi }
    return x
}

@inline(__always) func simd_normalize_d(_ v: Vec3) -> Vec3 { let l = simd_len(v); return l > 0 ? v / l : v }

func fmt(_ v: Double, _ d: Int) -> String { String(format: "%.\(d)f", v) }
