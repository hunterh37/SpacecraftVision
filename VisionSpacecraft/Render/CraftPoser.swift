import Foundation
import RealityKit
import RealKit
import SpacecraftCore

/// Marks a craft-part entity with its catalog id so flight state can find it.
struct PartTagComponent: Component {
    var partId: String
}

/// Drives RealityHD rig states and heat materials on a built craft from flight state.
@MainActor
final class CraftPoser {
    struct Input {
        var flying: Bool
        var altitude: Double
        var verticalSpeed: Double
        var speed: Double
        var throttle: Double
        var fuel: Double
        var chuteStage: Int
        var rates: Vec3
        var dt: Double
    }

    private var parts: [(id: String, entity: Entity)] = []
    private var lastState: [ObjectIdentifier: String] = [:]
    private var lastBucket: [ObjectIdentifier: Int] = [:]
    private var lidarAngle: Float = 0
    private var propAngle: Float = 0
    private var shieldHeat: Float = 0
    private var bellKelvin: Float = 300
    private var gearUp = false

    /// True when the craft carries a RealityHD parachute whose canopy states replace the stand-in canopies.
    private(set) var hasRiggedChute = false

    init(craft root: Entity) {
        PartTagComponent.registerComponent()
        func walk(_ e: Entity) {
            if let t = e.components[PartTagComponent.self] {
                parts.append((t.partId, e.name.hasSuffix("-mount") ? (e.children.first ?? e) : e))
                return
            }
            for c in e.children { walk(c) }
        }
        walk(root)
        hasRiggedChute = parts.contains { $0.id == "parachute" && $0.entity.articulationRoot != nil }
    }

    func reset() {
        lastState.removeAll(); lastBucket.removeAll()
        shieldHeat = 0; bellKelvin = 300; gearUp = false
        update(Input(flying: false, altitude: 0, verticalSpeed: 0, speed: 0, throttle: 0, fuel: 1, chuteStage: 0, rates: .zero, dt: 0))
    }

    func update(_ f: Input) {
        let dt = Float(f.dt)
        let pitchCmd = Float(max(-1, min(1, f.rates.x / 0.5)))
        let yawCmd = Float(max(-1, min(1, f.rates.y / 0.5)))
        let rollCmd = Float(max(-1, min(1, f.rates.z)))
        if f.altitude > 30 && f.verticalSpeed > 0 { gearUp = true }
        if f.altitude < 40 && f.verticalSpeed < 0 { gearUp = false }
        if !f.flying { gearUp = false }
        // Heat: stagnation heating rises with speed in air; shield char only accumulates.
        let air = Float(exp(-max(0, f.altitude) / 8500))
        let heating = max(0, (Float(f.speed) - 250) / 1800) * air
        shieldHeat = min(1, max(shieldHeat, heating))
        let targetK: Float = f.throttle > 0.01 ? 900 + 1100 * Float(f.throttle) : 300
        bellKelvin += (targetK - bellKelvin) * min(1, dt * (targetK > bellKelvin ? 2 : 0.3))
        if f.flying { lidarAngle = (lidarAngle + dt * 3600).truncatingRemainder(dividingBy: 360) }
        propAngle = (propAngle + dt * 360 * 40 * Float(f.throttle)).truncatingRemainder(dividingBy: 360)

        for (id, e) in parts {
            switch id {
            case "engine-liquid-small":
                let g = Float(PartCatalog.part(id)?.engine?.gimbalDeg ?? 6)
                e.setJoints(["pitch": pitchCmd * g, "yaw": yawCmd * g], animated: false)
                let bell = e.findEntity(named: "joint:yaw") ?? e
                apply(bell, bucket: Int(bellKelvin / 50)) { RealMaterialCache.shared.engineBellMaterial(kelvin: self.bellKelvin) }
            case "engine-solid-small":
                set(e, f.throttle > 0.01 ? "burning" : "idle")
            case "engine-prop":
                set(e, f.throttle > 0.01 ? "spinning" : (e.articulationStates.first ?? "idle"))
            case "parachute":
                set(e, f.chuteStage == 0 ? "packed" : f.chuteStage == 1 ? "drogue" : "main")
            case "landing-gear":
                set(e, gearUp ? "up" : "down")
            case "decoupler":
                set(e, f.flying && f.fuel <= 0.001 ? "separated" : "attached")
            case "elevon":
                set(e, pitchCmd > 0.2 ? "up" : pitchCmd < -0.2 ? "down" : "neutral")
            case "fin-trapezoid":
                set(e, rollCmd > 0.2 ? "cant-right" : rollCmd < -0.2 ? "cant-left" : "neutral")
            case "wing-section":
                set(e, rollCmd > 0.2 ? "aileron-up" : rollCmd < -0.2 ? "aileron-down" : "neutral")
            case "solar-panel":
                set(e, !f.flying || f.altitude > 2000 ? "deployed" : "stowed")
            case "lidar-sensor":
                e.setJoints(["head": lidarAngle], animated: false)
            case "heat-shield":
                apply(e, bucket: Int(shieldHeat * 20)) { RealMaterialCache.shared.ablativeMaterial(heat: self.shieldHeat) }
            default:
                break
            }
        }
    }

    private func set(_ e: Entity, _ state: String) {
        let k = ObjectIdentifier(e)
        guard lastState[k] != state, e.articulationStates.contains(state) else { return }
        lastState[k] = state
        e.setArticulation(state)
    }

    /// Replaces every material under `e` when the quantized bucket changes.
    private func apply(_ e: Entity, bucket: Int, _ make: () -> any RealityKit.Material) {
        let k = ObjectIdentifier(e)
        guard lastBucket[k] != bucket else { return }
        lastBucket[k] = bucket
        let m = make()
        func walk(_ x: Entity) {
            if var mc = x.components[ModelComponent.self] {
                mc.materials = Array(repeating: m, count: mc.materials.count)
                x.components.set(mc)
            }
            for c in x.children { walk(c) }
        }
        walk(e)
    }
}
