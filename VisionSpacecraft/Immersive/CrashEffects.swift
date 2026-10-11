import RealityKit
import SwiftUI

/// Crash effects for destructive failures: fireball burst, sparks, debris and a rising smoke column.
/// Entities and emitters are built once and re-armed per crash; nothing is allocated per frame.
@MainActor
final class CrashEffects {
    let root = Entity()
    private let fireball = Entity()
    private let sparks = Entity()
    private let smoke = Entity()
    private let flash = PointLight()
    private var debris: [ModelEntity] = []
    private var velocities: [SIMD3<Float>] = []
    private var spins: [SIMD3<Float>] = []
    private var age: Float = .infinity
    private static let life: Float = 7
    /// Blast size multiplier. Particle counts stay fixed; only extents, speeds and sizes scale.
    private static let blast: Float = 5
    /// Called with a debris piece on its first ground impact.
    var onImpact: ((Entity) -> Void)?
    private var landed: [Bool] = []

    /// Failure keys that destroy the craft.
    static func destroys(_ key: String?) -> Bool {
        guard let key else { return false }
        return ["fail.collision", "fail.structural", "fail.aero", "fail.heat"].contains(key)
    }

    init() {
        root.isEnabled = false
        fireball.components.set(Self.fireballEmitter())
        sparks.components.set(Self.sparkEmitter())
        smoke.components.set(Self.smokeEmitter())
        flash.light.color = UIColor(red: 1, green: 0.62, blue: 0.3, alpha: 1)
        flash.light.attenuationRadius = 60 * Self.blast
        flash.light.intensity = 0
        flash.position = [0, 2 * Self.blast, 0]
        for e in [fireball, sparks, smoke] as [Entity] + [flash] { root.addChild(e) }
        let mats: [RealityKit.Material] = [SimpleMaterial(color: UIColor(white: 0.18, alpha: 1), roughness: 0.8, isMetallic: true),
                                           SimpleMaterial(color: UIColor(white: 0.55, alpha: 1), roughness: 0.5, isMetallic: true)]
        let meshes = [MeshResource.generateBox(size: [0.5, 0.12, 0.35] * Self.blast), MeshResource.generateBox(size: [0.25, 0.25, 0.6] * Self.blast),
                      MeshResource.generateCylinder(height: 0.7 * Self.blast, radius: 0.15 * Self.blast)]
        for i in 0..<14 {
            let d = ModelEntity(mesh: meshes[i % meshes.count], materials: [mats[i % mats.count]])
            d.isEnabled = false
            root.addChild(d)
            debris.append(d)
        }
        velocities = Array(repeating: .zero, count: debris.count)
        spins = velocities
    }

    /// Detonates at a world-space point in the parent's frame. `scale` sizes the blast to the craft.
    func trigger(at p: SIMD3<Float>, scale: Float = 1) {
        root.position = p
        root.scale = .init(repeating: max(0.5, min(scale, 3)))
        root.isEnabled = true
        for e in [fireball, sparks, smoke] {
            guard var c = e.components[ParticleEmitterComponent.self] else { continue }
            c.restart(); c.isEmitting = true
            e.components.set(c)
        }
        for i in debris.indices {
            let a = Float.random(in: 0..<(2 * .pi)), up = Float.random(in: 6...16), out = Float.random(in: 3...10)
            velocities[i] = [cos(a) * out, up, sin(a) * out] * Self.blast
            spins[i] = SIMD3<Float>.random(in: -9...9)
            debris[i].position = (SIMD3<Float>.random(in: -0.4...0.4) + [0, 0.5, 0]) * Self.blast
            debris[i].isEnabled = true
        }
        landed = Array(repeating: false, count: debris.count)
        age = 0
    }

    func reset() {
        age = .infinity
        root.isEnabled = false
        for e in [fireball, sparks, smoke] {
            guard var c = e.components[ParticleEmitterComponent.self] else { continue }
            c.isEmitting = false
            e.components.set(c)
        }
        for d in debris { d.isEnabled = false }
    }

    func update(dt: Float) {
        guard age < Self.life else { return }
        age += dt
        flash.light.intensity = max(0, 1 - age / 0.6) * 400_000 * Self.blast * Self.blast
        if age > 0.35, var c = fireball.components[ParticleEmitterComponent.self], c.isEmitting {
            c.isEmitting = false; fireball.components.set(c)
        }
        if age > 0.6, var c = sparks.components[ParticleEmitterComponent.self], c.isEmitting {
            c.isEmitting = false; sparks.components.set(c)
        }
        if age > Self.life - 2.5, var c = smoke.components[ParticleEmitterComponent.self], c.isEmitting {
            c.isEmitting = false; smoke.components.set(c)
        }
        for i in debris.indices where debris[i].isEnabled {
            var p = debris[i].position
            if p.y <= 0.05 && velocities[i].y <= 0 { continue }   // at rest on the ground
            velocities[i].y -= 9.81 * Self.blast * dt
            p += velocities[i] * dt
            if p.y < 0.05 {
                if !landed[i] { landed[i] = true; onImpact?(debris[i]) }
                p.y = 0.05; velocities[i] *= SIMD3(0.4, -0.25, 0.4); spins[i] *= 0.4 }
            debris[i].position = p
            debris[i].orientation = simd_quatf(angle: simd_length(spins[i]) * dt, axis: simd_normalize(spins[i] + 1e-4)) * debris[i].orientation
        }
    }

    // MARK: Emitters

    private static func fireballEmitter() -> ParticleEmitterComponent {
        var c = ParticleEmitterComponent()
        c.emitterShape = .sphere
        c.emitterShapeSize = [1.2, 1.2, 1.2] * blast
        c.birthLocation = .volume
        c.birthDirection = .normal
        c.speed = 7 * blast; c.speedVariation = 3 * blast
        c.isEmitting = false
        c.timing = .once(warmUp: nil, emit: .init(duration: 0.25))
        c.mainEmitter.birthRate = 900
        c.mainEmitter.lifeSpan = 0.9; c.mainEmitter.lifeSpanVariation = 0.3
        c.mainEmitter.size = 1.4 * blast; c.mainEmitter.sizeVariation = 0.6 * blast
        c.mainEmitter.sizeMultiplierAtEndOfLifespan = 2.2
        c.mainEmitter.dampingFactor = 4
        c.mainEmitter.blendMode = .additive
        c.mainEmitter.color = .evolving(start: .single(.init(red: 1, green: 0.85, blue: 0.45, alpha: 1)),
                                        end: .single(.init(red: 0.8, green: 0.2, blue: 0.05, alpha: 0)))
        c.mainEmitter.opacityCurve = .quickFadeInOut
        c.mainEmitter.spreadingAngle = .pi
        return c
    }

    private static func sparkEmitter() -> ParticleEmitterComponent {
        var c = ParticleEmitterComponent()
        c.emitterShape = .point
        c.birthDirection = .world
        c.emissionDirection = [0, 1, 0]
        c.speed = 16 * blast; c.speedVariation = 7 * blast
        c.isEmitting = false
        c.timing = .once(warmUp: nil, emit: .init(duration: 0.15))
        c.mainEmitter.birthRate = 1500
        c.mainEmitter.lifeSpan = 1.4; c.mainEmitter.lifeSpanVariation = 0.5
        c.mainEmitter.size = 0.08 * blast; c.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.2
        c.mainEmitter.spreadingAngle = 1.3
        c.mainEmitter.acceleration = [0, -9.8 * blast, 0]
        c.mainEmitter.blendMode = .additive
        c.mainEmitter.stretchFactor = 4
        c.mainEmitter.color = .evolving(start: .single(.init(red: 1, green: 0.9, blue: 0.6, alpha: 1)),
                                        end: .single(.init(red: 1, green: 0.3, blue: 0.05, alpha: 0)))
        return c
    }

    private static func smokeEmitter() -> ParticleEmitterComponent {
        var c = ParticleEmitterComponent()
        c.emitterShape = .sphere
        c.emitterShapeSize = [1.5, 0.5, 1.5] * blast
        c.birthDirection = .world
        c.emissionDirection = [0, 1, 0]
        c.speed = 2.5 * blast; c.speedVariation = 1 * blast
        c.isEmitting = false
        c.timing = .repeating(warmUp: nil, emit: .init(duration: 1), idle: nil)
        c.mainEmitter.birthRate = 45
        c.mainEmitter.lifeSpan = 5; c.mainEmitter.lifeSpanVariation = 1.5
        c.mainEmitter.size = 1.6 * blast; c.mainEmitter.sizeVariation = 0.5 * blast
        c.mainEmitter.sizeMultiplierAtEndOfLifespan = 4
        c.mainEmitter.spreadingAngle = 0.35
        c.mainEmitter.acceleration = [0.4, 0.6, 0] * blast
        c.mainEmitter.dampingFactor = 0.3
        c.mainEmitter.angularSpeedVariation = 0.8
        c.mainEmitter.blendMode = .alpha
        c.mainEmitter.isLightingEnabled = false
        c.mainEmitter.color = .evolving(start: .single(.init(red: 0.12, green: 0.1, blue: 0.09, alpha: 0.85)),
                                        end: .single(.init(red: 0.45, green: 0.43, blue: 0.42, alpha: 0)))
        c.mainEmitter.opacityCurve = .gradualFadeInOut
        return c
    }
}
