import Foundation

/// A part placed on the craft. Stack parts form the vertical axis top to bottom; radial parts
/// mount on a stack part with radial symmetry `count`.
public struct PartInstance: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var partId: String
    /// Fuel load 0...1 for tanks (5% steps in the workshop).
    public var fuelLoad: Double
    /// Radial parts: the stack part they mount on and the symmetry count.
    public var parentId: UUID?
    public var count: Int
    public var paint: String

    public init(id: UUID = UUID(), partId: String, fuelLoad: Double = 1, parentId: UUID? = nil, count: Int = 1,
                paint: String = "F2F2F0") {
        self.id = id; self.partId = partId; self.fuelLoad = fuelLoad; self.parentId = parentId; self.count = count
        self.paint = paint
    }

    public var definition: PartDefinition { PartCatalog[partId] }
}

public struct CraftDesign: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var stack: [PartInstance]
    public var radial: [PartInstance]
    public var payloadMass: Double

    public init(id: UUID = UUID(), name: String = "Untitled", stack: [PartInstance] = [], radial: [PartInstance] = [],
                payloadMass: Double = 0) {
        self.id = id; self.name = name; self.stack = stack; self.radial = radial; self.payloadMass = payloadMass
    }

    /// Bottom of the stack sits at 0; returns (bottom z, top z) of each stack part.
    public var stackSpans: [(bottom: Double, top: Double)] {
        var z = stack.reduce(0) { $0 + $1.definition.length }
        return stack.map { p in
            let top = z; z -= p.definition.length
            return (z, top)
        }
    }

    public var height: Double { stack.reduce(0) { $0 + $1.definition.length } }

    public mutating func setFuelLoad(_ load: Double) {
        for i in stack.indices where stack[i].definition.propellantMass > 0 { stack[i].fuelLoad = load }
        for i in radial.indices where radial[i].definition.propellantMass > 0 && !(radial[i].definition.engine?.solid ?? false) {
            radial[i].fuelLoad = load
        }
    }

    /// Reference craft R-hop (specs/15).
    public static func rHop(fuelLoad: Double = 0.10, payload: Double = 20) -> CraftDesign {
        let nose = PartInstance(partId: "nose-cone")
        let probe = PartInstance(partId: "probe-core")
        let tank = PartInstance(partId: "fuel-tank-s", fuelLoad: fuelLoad)
        let engine = PartInstance(partId: "engine-liquid-small")
        return CraftDesign(name: "R-hop", stack: [nose, probe, tank, engine], radial: [
            PartInstance(partId: "imu", parentId: probe.id),
            PartInstance(partId: "battery-pack", parentId: probe.id),
            PartInstance(partId: "parachute", parentId: probe.id),
            PartInstance(partId: "fin-trapezoid", parentId: engine.id, count: 4),
        ], payloadMass: payload)
    }

    public static func rGates() -> CraftDesign {
        var c = rHop(fuelLoad: 1.0); c.name = "R-gates"; return c
    }
}

public struct CraftStats: Sendable, Hashable {
    public var dryMass: Double
    public var propellantMass: Double
    public var wetMass: Double { dryMass + propellantMass }
    public var cost: Int
    public var partCount: Int
    /// Centre of mass height above the stack bottom, m.
    public var centerOfMass: Double
    /// Centre of thrust height (engine bottoms), m; nil without engines.
    public var centerOfThrust: Double?
    public var thrustSL: Double
    public var thrustVac: Double
    public var twrSL: Double
    public var deltaVSL: Double
    public var deltaVVac: Double
    public var energyWh: Double
    public var lowestHeatLimit: Double
    public var hasCommand: Bool
    public var hasParachute: Bool
    public var frontalCdA: Double
}

public extension CraftDesign {
    /// All parts with symmetry expanded, as (definition, instance, height of part centre).
    var expandedParts: [(def: PartDefinition, inst: PartInstance, z: Double)] {
        var out: [(PartDefinition, PartInstance, Double)] = []
        let spans = stackSpans
        var zOf: [UUID: (bottom: Double, top: Double)] = [:]
        for (i, p) in stack.enumerated() {
            zOf[p.id] = spans[i]
            out.append((p.definition, p, (spans[i].bottom + spans[i].top) / 2))
        }
        for r in radial {
            guard let span = zOf[r.parentId ?? UUID()] else { continue }
            let d = r.definition
            let z = d.realityHDId == "fin-trapezoid" ? span.bottom + d.length / 2 : (span.bottom + span.top) / 2
            for _ in 0..<max(1, r.count) { out.append((d, r, z)) }
        }
        return out
    }

    func stats() -> CraftStats {
        let parts = expandedParts
        var dry = payloadMass, prop = 0.0, moment = 0.0, cost = 0, energy = 0.0, heat = Double.infinity
        let topZ = height
        moment += payloadMass * topZ * 0.8
        var thrustSL = 0.0, thrustVac = 0.0, mdot = 0.0, cotSum = 0.0
        for (d, inst, z) in parts {
            let pm = d.propellantMass * (d.engine?.solid == true ? 1 : inst.fuelLoad)
            dry += d.dryMass; prop += pm
            moment += (d.dryMass + pm) * z
            cost += d.cost
            energy += d.batteryWh ?? 0
            heat = min(heat, d.maxTemp)
            if let e = d.engine, d.realityHDId != "engine-prop" {
                thrustSL += e.thrustSL; thrustVac += e.thrustVac; mdot += e.mdot
                cotSum += e.thrustSL * (z - d.length / 2)
            }
        }
        let wet = dry + prop
        let ispSL = mdot > 0 ? thrustSL / (mdot * g0) : 0
        let ispVac = mdot > 0 ? thrustVac / (mdot * g0) : 0
        let ratio = dry > 0 ? wet / dry : 1
        let top = stack.first?.definition
        return CraftStats(
            dryMass: dry, propellantMass: prop, cost: cost, partCount: parts.count,
            centerOfMass: wet > 0 ? moment / wet : 0, centerOfThrust: thrustSL > 0 ? cotSum / thrustSL : nil,
            thrustSL: thrustSL, thrustVac: thrustVac, twrSL: wet > 0 ? thrustSL / (wet * g0) : 0,
            deltaVSL: ispSL * g0 * log(ratio), deltaVVac: ispVac * g0 * log(ratio), energyWh: energy,
            lowestHeatLimit: heat.isFinite ? heat : 0,
            hasCommand: parts.contains { $0.def.category == .command },
            hasParachute: parts.contains { $0.def.parachute != nil },
            frontalCdA: (top?.cdSubsonic ?? 0) * (top?.dragArea ?? 0))
    }
}
