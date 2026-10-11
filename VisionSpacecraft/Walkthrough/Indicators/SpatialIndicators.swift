import RealityKit
import UIKit

/// White unlit indicator kit for the range walkthrough: pad beacon (ground ring + light column), target halo,
/// leader dots from the callout to the target and a success burst. Built once, toggled per step.
@MainActor
final class SpatialIndicators {
    /// World-space parent (content root); leader dots and burst live here.
    let world = Entity()
    /// Course-space parent; pad beacon lives under the range root so it follows view changes.
    let course = Entity()
    let padRing: ModelEntity
    let padColumn: ModelEntity
    let halo: ModelEntity
    let burst: ModelEntity
    private var dots: [ModelEntity] = []
    private var burstAge: Float = 1
    private var clock: Float = 0
    private let reduceMotion = UIAccessibility.isReduceMotionEnabled

    init() {
        padRing = Self.ring(inner: 4.2, outer: 4.6, alpha: 0.9)
        padRing.position = [0, 0.08, 0]
        padColumn = ModelEntity(mesh: .generateCylinder(height: 40, radius: 0.12), materials: [Self.white(0.35)])
        padColumn.position = [0, 20, 0]
        course.addChild(padRing)
        course.addChild(padColumn)

        halo = Self.ring(inner: 0.92, outer: 1.0, alpha: 0.9)
        world.addChild(halo)

        burst = Self.ring(inner: 0.9, outer: 1.0, alpha: 1)
        burst.components.set(OpacityComponent(opacity: 0))
        world.addChild(burst)

        let dotMesh = MeshResource.generateSphere(radius: 1)
        for _ in 0..<14 {
            let d = ModelEntity(mesh: dotMesh, materials: [Self.white(0.8)])
            world.addChild(d)
            dots.append(d)
        }
        hideAll()
    }

    func hideAll() {
        for e in [padRing, padColumn, halo] as [Entity] { e.isEnabled = false }
        for d in dots { d.isEnabled = false }
    }

    /// Show the indicator group for a target. `from` is the callout's world position; `to` the target's.
    func show(beacon: Bool, haloAt: (SIMD3<Float>, Float)?, leader: (from: SIMD3<Float>, to: SIMD3<Float>)?) {
        padRing.isEnabled = beacon
        padColumn.isEnabled = beacon
        if let (p, r) = haloAt {
            halo.isEnabled = true
            halo.position = p
            halo.scale = .init(repeating: r)
        } else { halo.isEnabled = false }
        guard let leader else { for d in dots { d.isEnabled = false }; return }
        let v = leader.to - leader.from
        let dist = simd_length(v)
        for (i, d) in dots.enumerated() {
            // Quadratic spacing: dense near the callout, sparse toward a distant target.
            let f = pow(Float(i + 1) / Float(dots.count + 1), 2)
            let p = leader.from + v * f
            d.isEnabled = dist > 0.2
            d.position = p
            d.scale = .init(repeating: 0.004 + 0.006 * f * dist)
        }
    }

    func playBurst(at p: SIMD3<Float>) {
        burst.position = p
        burstAge = 0
    }

    /// Breathing pulse and burst fade, called from the scene update.
    func tick(_ dt: Float) {
        clock += dt
        let pulse: Float = reduceMotion ? 1 : 1 + 0.06 * sin(clock * 2.4)
        padRing.scale = [pulse, 1, pulse]
        if halo.isEnabled {
            let s = halo.scale.x
            halo.orientation = simd_quatf(angle: reduceMotion ? 0 : clock * 0.4, axis: [0, 1, 0])
            halo.scale = [s, 1, s]
        }
        if burstAge < 1 {
            burstAge = min(1, burstAge + dt / 0.4)
            let e = 1 - pow(1 - burstAge, 3)
            burst.scale = .init(repeating: 0.05 + 0.25 * e)
            burst.components.set(OpacityComponent(opacity: 1 - burstAge))
            // Face the viewer: rings are flat in xz, stand them up.
            burst.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        }
    }

    static func white(_ a: CGFloat) -> UnlitMaterial { PartMeshFactory.unlit(0xFFFFFF, alpha: a) }

    /// Flat double-sided annulus in the xz plane.
    static func ring(inner: Float, outer: Float, alpha: CGFloat, segments: Int = 64) -> ModelEntity {
        var pos: [SIMD3<Float>] = [], idx: [UInt32] = []
        for i in 0..<segments {
            let a = Float(i) / Float(segments) * 2 * .pi
            pos.append([cos(a) * inner, 0, sin(a) * inner])
            pos.append([cos(a) * outer, 0, sin(a) * outer])
        }
        let n = UInt32(segments * 2)
        for i in 0..<UInt32(segments) {
            let a = i * 2, b = a + 1, c = (a + 2) % n, d = (a + 3) % n
            idx += [a, b, c, c, b, d]      // top
            idx += [a, c, b, c, d, b]      // bottom
        }
        var desc = MeshDescriptor(name: "ring")
        desc.positions = MeshBuffers.Positions(pos)
        desc.primitives = .triangles(idx)
        let mesh = (try? MeshResource.generate(from: [desc])) ?? .generateSphere(radius: 0.01)
        return ModelEntity(mesh: mesh, materials: [white(alpha)])
    }
}
