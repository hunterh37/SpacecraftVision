import Foundation

public let g0 = 9.80665

public enum PartCategory: String, Codable, Sendable, CaseIterable {
    case command, tank, engine, aero, structure, recovery, power, sensor
}

/// How a part joins the craft in the slice: stacked on the vertical axis, or mounted radially on a stack part.
public enum MountKind: String, Codable, Sendable { case stack, radial }

public struct EngineSpec: Codable, Sendable, Hashable {
    public var thrustSL: Double
    public var thrustVac: Double
    public var ispSL: Double
    public var ispVac: Double
    public var mdot: Double
    public var throttleMin: Double
    public var gimbalDeg: Double
    public var solid: Bool
    public var heatFraction: Double

    public func isp(pressure p: Double) -> Double {
        let f = min(max(p / Atmosphere.seaLevelPressure, 0), 1)
        return ispVac + (ispSL - ispVac) * f
    }

    public func thrust(pressure p: Double, throttle: Double) -> Double {
        throttle * mdot * g0 * isp(pressure: p)
    }
}

public struct ParachuteSpec: Codable, Sendable, Hashable {
    public var drogueArea: Double = 12.6
    public var drogueCd: Double = 0.55
    public var drogueLimit: Double = 90
    public var drogueOpen: Double = 1.5
    public var mainArea: Double = 201
    public var mainCd: Double = 0.85
    public var mainLimit: Double = 35
    public var mainOpen: Double = 4.0
}

public struct PartDefinition: Codable, Sendable, Hashable, Identifiable {
    public var id: String { realityHDId }
    public var realityHDId: String
    public var displayName: String
    public var category: PartCategory
    public var mount: MountKind
    public var dryMass: Double
    public var propellantMass: Double
    /// Diameter (or largest width) and length along the stack axis, m.
    public var diameter: Double
    public var length: Double
    public var cost: Int
    public var unlockLesson: Int
    public var material: String
    public var maxTemp: Double
    public var maxG: Double
    public var maxQkPa: Double
    public var jointAxialKN: Double
    public var jointLateralKN: Double
    public var dragArea: Double
    public var cdSubsonic: Double
    public var cdTransonic: Double
    public var electricDraw: Double
    public var engine: EngineSpec?
    public var batteryWh: Double?
    public var parachute: ParachuteSpec?
    public var sourceNote: String

    public var wetMass: Double { dryMass + propellantMass }

    /// Cd at Mach, linear between 0.3 and 1.1, 70% of peak above Mach 3.
    public func cd(mach: Double) -> Double {
        if mach <= 0.3 { return cdSubsonic }
        if mach <= 1.1 { return cdSubsonic + (cdTransonic - cdSubsonic) * (mach - 0.3) / 0.8 }
        if mach >= 3 { return cdTransonic * 0.7 }
        return cdTransonic + (cdTransonic * 0.7 - cdTransonic) * (mach - 1.1) / 1.9
    }
}

/// Part constants from specs/14-parts-catalog.md.
public enum PartCatalog {
    private static func p(_ id: String, _ name: String, _ cat: PartCategory, _ mount: MountKind,
                          dry: Double, prop: Double = 0, dia: Double, len: Double, cost: Int, unlock: Int,
                          material: String, maxT: Double, maxG: Double, maxQ: Double, joint: (Double, Double),
                          area: Double, cd: (Double, Double), draw: Double = 0, engine: EngineSpec? = nil,
                          battery: Double? = nil, chute: ParachuteSpec? = nil, source: String) -> PartDefinition {
        PartDefinition(realityHDId: id, displayName: name, category: cat, mount: mount, dryMass: dry, propellantMass: prop,
                       diameter: dia, length: len, cost: cost, unlockLesson: unlock, material: material, maxTemp: maxT,
                       maxG: maxG, maxQkPa: maxQ, jointAxialKN: joint.0, jointLateralKN: joint.1, dragArea: area,
                       cdSubsonic: cd.0, cdTransonic: cd.1, electricDraw: draw, engine: engine, batteryWh: battery,
                       parachute: chute, sourceNote: source)
    }

    public static let all: [PartDefinition] = [
        p("command-pod", "Command pod Mk1", .command, .stack, dry: 840, dia: 1.25, len: 1.4, cost: 18_000, unlock: 10,
          material: "titanium shell", maxT: 1200, maxG: 20, maxQ: 150, joint: (150, 40), area: 1.227, cd: (1.10, 1.60),
          draw: 60, battery: 1000, source: "NASA Mercury capsule mass and drag (NASA SP-45), scaled to 1.25 m"),
        p("probe-core", "Probe core", .command, .stack, dry: 45, dia: 1.25, len: 0.4, cost: 4_000, unlock: 0,
          material: "aluminum", maxT: 600, maxG: 30, maxQ: 120, joint: (80, 20), area: 1.227, cd: (0.80, 1.30),
          draw: 20, battery: 50, source: "Smallsat avionics ring, Electron kick stage avionics bay class"),
        p("fuel-tank-s", "Fuel tank S", .tank, .stack, dry: 65, prop: 950, dia: 1.25, len: 1.0, cost: 1_500, unlock: 0,
          material: "aluminum", maxT: 600, maxG: 20, maxQ: 100, joint: (120, 30), area: 1.227, cd: (0.80, 1.30),
          source: "Al 2219 propellant tanks at 6% tank mass fraction, Rocket Lab Electron second stage class"),
        p("fuel-tank-m", "Fuel tank M", .tank, .stack, dry: 120, prop: 1900, dia: 1.25, len: 2.0, cost: 2_500, unlock: 2,
          material: "aluminum", maxT: 600, maxG: 20, maxQ: 100, joint: (120, 30), area: 1.227, cd: (0.80, 1.30),
          source: "Al 2219 propellant tanks at 6% tank mass fraction, Rocket Lab Electron second stage class"),
        p("fuel-tank-l", "Fuel tank L", .tank, .stack, dry: 230, prop: 3800, dia: 1.25, len: 4.0, cost: 4_200, unlock: 7,
          material: "aluminum", maxT: 600, maxG: 20, maxQ: 100, joint: (150, 40), area: 1.227, cd: (0.80, 1.30),
          source: "Al 2219 propellant tanks at 6% tank mass fraction, Rocket Lab Electron second stage class"),
        p("engine-solid-small", "Solid motor S", .engine, .radial, dry: 90, prop: 410, dia: 0.6, len: 1.8, cost: 2_200, unlock: 7,
          material: "steel case", maxT: 1100, maxG: 25, maxQ: 100, joint: (45, 40), area: 0.283, cd: (0.45, 0.80),
          engine: EngineSpec(thrustSL: 18_400, thrustVac: 20_000, ispSL: 230, ispVac: 250, mdot: 8.15, throttleMin: 1,
                             gimbalDeg: 0, solid: true, heatFraction: 0.004),
          source: "Improved Orion / Nammo sounding rocket motor class, APCP Isp, scaled"),
        p("engine-liquid-small", "Liquid engine S", .engine, .stack, dry: 75, dia: 1.25, len: 1.5, cost: 6_500, unlock: 0,
          material: "steel", maxT: 1100, maxG: 20, maxQ: 100, joint: (60, 15), area: 1.227, cd: (0.12, 0.25),
          engine: EngineSpec(thrustSL: 24_000, thrustVac: 26_300, ispSL: 285, ispVac: 312, mdot: 8.60, throttleMin: 0.4,
                             gimbalDeg: 6, solid: false, heatFraction: 0.002),
          source: "Rocket Lab Rutherford (24 kN SL, 311 s vac), mount mass added; 40% throttle floor from Merlin 1D"),
        p("engine-prop", "Electric propeller", .engine, .stack, dry: 70, dia: 1.8, len: 0.9, cost: 5_000, unlock: 4,
          material: "composite", maxT: 450, maxG: 15, maxQ: 15, joint: (10, 5), area: 0.20, cd: (0.30, 0.30),
          source: "Pipistrel Velis Electro E-811 motor, momentum theory thrust"),
        p("nose-cone", "Nose cone", .aero, .stack, dry: 35, dia: 1.25, len: 1.2, cost: 900, unlock: 0,
          material: "aluminum skin, composite tip", maxT: 600, maxG: 20, maxQ: 120, joint: (30, 10), area: 1.227,
          cd: (0.30, 0.55), source: "OpenRocket ogive drag tables"),
        p("fin-trapezoid", "Fin", .aero, .radial, dry: 9, dia: 0.6, len: 0.9, cost: 300, unlock: 0,
          material: "aluminum", maxT: 600, maxG: 30, maxQ: 60, joint: (5, 3), area: 0.012, cd: (0.10, 0.40),
          source: "Barrowman method, OpenRocket fin drag"),
        p("wing-section", "Wing section", .aero, .radial, dry: 27, dia: 3.9, len: 1.4, cost: 700, unlock: 4,
          material: "composite", maxT: 450, maxG: 6, maxQ: 6, joint: (5, 15), area: 4.49, cd: (0.008, 0.008),
          source: "OpenVSP VSPAERO tables; light composite airframe 6 kg/m²"),
        p("elevon", "Elevon", .aero, .radial, dry: 4, dia: 1.0, len: 0.3, cost: 400, unlock: 4,
          material: "composite", maxT: 450, maxG: 20, maxQ: 6, joint: (2, 2), area: 0.003, cd: (0.10, 0.10),
          draw: 0, source: "OpenVSP VSPAERO tables; light composite airframe 6 kg/m²"),
        p("fuselage-section", "Fuselage section", .structure, .stack, dry: 25, dia: 1.25, len: 2.0, cost: 800, unlock: 4,
          material: "composite", maxT: 450, maxG: 15, maxQ: 30, joint: (40, 20), area: 1.227, cd: (0.80, 0.80),
          source: "Light composite airframe, Pipistrel Alpha class"),
        p("decoupler", "Decoupler", .structure, .stack, dry: 30, dia: 1.25, len: 0.2, cost: 800, unlock: 2,
          material: "aluminum", maxT: 600, maxG: 25, maxQ: 100, joint: (120, 30), area: 1.227, cd: (0.80, 1.30),
          source: "Spring separation systems, Planetary Systems Lightband class"),
        p("parachute", "Parachute", .recovery, .radial, dry: 18, dia: 0.4, len: 0.3, cost: 900, unlock: 0,
          material: "nylon", maxT: 450, maxG: 20, maxQ: 120, joint: (40, 40), area: 0.02, cd: (1.0, 1.4),
          chute: ParachuteSpec(),
          source: "Knacke, Parachute Recovery Systems Design Manual: ribbon drogue Cd 0.55, round main Cd 0.85"),
        p("heat-shield", "Heat shield", .structure, .stack, dry: 60, dia: 1.25, len: 0.15, cost: 1_500, unlock: 10,
          material: "ablator on aluminum", maxT: 2400, maxG: 25, maxQ: 200, joint: (150, 40), area: 1.227,
          cd: (1.10, 1.60), source: "NASA Ames PICA heat of ablation"),
        p("landing-gear", "Landing gear", .structure, .radial, dry: 15, dia: 0.3, len: 0.9, cost: 500, unlock: 4,
          material: "steel", maxT: 600, maxG: 15, maxQ: 1.5, joint: (12, 4), area: 0.08, cd: (1.0, 1.0),
          source: "Light aircraft spring steel fixed gear, Cessna 150 class"),
        p("battery-pack", "Battery pack", .power, .radial, dry: 14, dia: 0.4, len: 0.3, cost: 1_200, unlock: 0,
          material: "Li-ion NMC", maxT: 333, maxG: 30, maxQ: 40, joint: (3, 3), area: 0.06, cd: (1.0, 1.4),
          battery: 2500, source: "Li-ion NMC 250 Wh/kg cells, 72% pack fraction"),
        p("solar-panel", "Solar panel", .power, .radial, dry: 6, dia: 1.6, len: 0.6, cost: 700, unlock: 4,
          material: "Si cells, composite", maxT: 450, maxG: 10, maxQ: 50, joint: (1, 1), area: 0.01, cd: (1.2, 1.5),
          source: "Monocrystalline Si 22% at 1,000 W/m²"),
        p("lidar-sensor", "Lidar", .sensor, .radial, dry: 0.8, dia: 0.15, len: 0.1, cost: 3_000, unlock: 3,
          material: "electronics", maxT: 358, maxG: 50, maxQ: 40, joint: (1, 1), area: 0.015, cd: (1.0, 1.4),
          draw: 18, source: "Ouster OS1 class (120 m, 10 Hz, ±3 cm, 14 to 20 W)"),
        p("radar-sensor", "Radar", .sensor, .radial, dry: 3.0, dia: 0.3, len: 0.12, cost: 6_000, unlock: 7,
          material: "electronics", maxT: 358, maxG: 50, maxQ: 25, joint: (2, 2), area: 0.036, cd: (1.0, 1.4),
          draw: 60, source: "Echodyne EchoFlight class detect-and-avoid radar"),
        p("camera-sensor", "Camera", .sensor, .radial, dry: 0.25, dia: 0.1, len: 0.1, cost: 1_500, unlock: 9,
          material: "electronics", maxT: 358, maxG: 50, maxQ: 40, joint: (0.5, 0.5), area: 0.010, cd: (1.05, 1.4),
          draw: 15, source: "Machine-vision camera with Jetson Orin Nano class detector"),
        p("imu", "IMU", .sensor, .radial, dry: 1.2, dia: 0.1, len: 0.1, cost: 2_500, unlock: 0,
          material: "electronics", maxT: 358, maxG: 50, maxQ: 40, joint: (0.5, 0.5), area: 0.010, cd: (1.05, 1.4),
          draw: 5, source: "Tactical MEMS IMU with GNSS, Honeywell HG4930 class"),
        // Saturn V / Apollo stack (specs/14, Saturn V reference craft). Masses are AS-506 flight values.
        p("saturn-s1c", "Saturn V S-IC", .engine, .stack, dry: 130_000, prop: 2_160_000, dia: 10.06, len: 42.1, cost: 2_400_000,
          unlock: 10, material: "Al 2219 skin, steel thrust structure", maxT: 900, maxG: 6, maxQ: 40, joint: (40_000, 8_000),
          area: 79.5, cd: (0.35, 0.60),
          engine: EngineSpec(thrustSL: 33_850_000, thrustVac: 38_850_000, ispSL: 263, ispVac: 304, mdot: 12_890, throttleMin: 1,
                             gimbalDeg: 6, solid: false, heatFraction: 0.0005),
          source: "Saturn V Flight Manual SA-503 and AS-506 evaluation report: 5x F-1, 6,770 kN SL each, RP-1/LOX"),
        p("saturn-s2", "Saturn V S-II", .engine, .stack, dry: 40_100, prop: 444_000, dia: 10.06, len: 24.9, cost: 1_300_000,
          unlock: 10, material: "Al 2014 skin, foam-insulated LH2 tank", maxT: 700, maxG: 6, maxQ: 40, joint: (12_000, 3_000),
          area: 79.5, cd: (0.80, 1.30),
          engine: EngineSpec(thrustSL: 2_430_000, thrustVac: 5_165_000, ispSL: 200, ispVac: 421, mdot: 1_250, throttleMin: 1,
                             gimbalDeg: 7, solid: false, heatFraction: 0.0005),
          source: "Saturn V Flight Manual: 5x J-2 (1,033 kN vac each), dry mass includes the S-IC/S-II interstage"),
        p("saturn-s4b", "Saturn V S-IVB", .engine, .stack, dry: 15_200, prop: 109_500, dia: 10.06, len: 17.8, cost: 650_000,
          unlock: 10, material: "Al 2014 skin, internal LH2 insulation", maxT: 700, maxG: 6, maxQ: 40, joint: (6_000, 1_500),
          area: 79.5, cd: (0.80, 1.30),
          engine: EngineSpec(thrustSL: 486_000, thrustVac: 1_033_000, ispSL: 200, ispVac: 421, mdot: 250, throttleMin: 1,
                             gimbalDeg: 7, solid: false, heatFraction: 0.0005),
          source: "Saturn V Flight Manual: 1x J-2 restartable, dry mass includes the S-II/S-IVB conical interstage"),
        p("saturn-iu", "Saturn V instrument unit", .command, .stack, dry: 2_000, dia: 6.6, len: 0.91, cost: 300_000, unlock: 10,
          material: "aluminum honeycomb", maxT: 400, maxG: 8, maxQ: 40, joint: (3_000, 800), area: 34.2, cd: (0.80, 1.30),
          draw: 2_200, battery: 18_000, source: "IBM Saturn V IU: ST-124M inertial platform, LVDC, silver-zinc batteries"),
        p("apollo-sla", "Spacecraft LM adapter", .structure, .stack, dry: 1_800, dia: 6.6, len: 8.5, cost: 120_000, unlock: 10,
          material: "aluminum honeycomb", maxT: 600, maxG: 8, maxQ: 40, joint: (2_500, 700), area: 34.2, cd: (0.50, 0.80),
          source: "Apollo SLA, North American Rockwell: 6.6 to 3.9 m truncated cone"),
        p("apollo-csm", "Apollo CSM", .command, .stack, dry: 11_670, prop: 18_410, dia: 3.91, len: 7.2, cost: 900_000, unlock: 10,
          material: "aluminum honeycomb, steel heat shield substructure", maxT: 2700, maxG: 15, maxQ: 60, joint: (1_500, 400),
          area: 12.0, cd: (0.50, 0.85), draw: 1_400,
          engine: EngineSpec(thrustSL: 0, thrustVac: 91_190, ispSL: 0, ispVac: 314, mdot: 29.6, throttleMin: 1, gimbalDeg: 6,
                             solid: false, heatFraction: 0.0005),
          battery: 6_000,
          source: "Apollo Operations Handbook Block II: CM 5,560 kg, SM 6,110 kg dry, SPS AJ10-137 91.2 kN"),
        p("apollo-les", "Launch escape system", .aero, .stack, dry: 4_170, dia: 1.26, len: 9.2, cost: 200_000, unlock: 10,
          material: "steel truss, solid motor case", maxT: 900, maxG: 20, maxQ: 60, joint: (400, 100), area: 0.35, cd: (0.30, 0.55),
          source: "Apollo LES: tower jettison and escape motors carried as mass; abort not simulated"),
    ]

    private static let byId: [String: PartDefinition] = Dictionary(uniqueKeysWithValues: all.map { ($0.realityHDId, $0) })

    public static func part(_ id: String) -> PartDefinition? { byId[id] }
    public static subscript(_ id: String) -> PartDefinition { byId[id]! }
}
