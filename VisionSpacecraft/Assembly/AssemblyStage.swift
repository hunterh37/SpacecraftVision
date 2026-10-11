import Foundation
import RealityKit
import UIKit
import SpacecraftCore

/// RealityKit side of the guided build (specs/18): life-size parts on a rack beside the pad, a ghost of
/// the next part at its target with a node ring, arc animation for Watch build, drag snap and lock.
@MainActor
final class AssemblyStage {
    let rack = Entity()
    /// Child of the craft holder, so the ghost follows tabletop scale.
    let ghost = Entity()
    private var ring: ModelEntity?
    private var homes: [Int: Transform] = [:]
    private var grabOffset: SIMD3<Float>?
    private(set) var snapped = false

    static let telemetry: UInt32 = 0x4FDBF2
    static let ignition: UInt32 = 0xFF6B21
    static let trajectory: UInt32 = 0xB78FFF

    init() {
        rack.name = "assembly-rack"
        ghost.name = "assembly-ghost"
    }

    // MARK: Layout

    /// Rack slot for the k-th remaining part: stack parts stand on the floor in a row left of the pad,
    /// radial parts sit on plinths in a second row.
    static func slot(_ k: Int, radial: Bool) -> SIMD3<Float> {
        radial ? [-3.4, 0.9, -1.4 - Float(k) * 0.8] : [-2.3, 0, -1.2 - Float(k) * 1.1]
    }

    func rebuild(plan: AssemblyPlan?, index: Int, showRack: Bool, craftHolder: Entity) async {
        rack.children.removeAll()
        ghost.children.removeAll()
        homes = [:]
        ring = nil
        snapped = false
        guard let plan, showRack else { return }
        var ks = 0, kr = 0
        for i in index..<plan.count {
            let step = plan.steps[i]
            let radial: Bool = { if case .radial = step.node { return true }; return false }()
            let k = radial ? kr : ks
            if radial { kr += 1 } else { ks += 1 }
            let wrap = Entity()
            wrap.name = "rack-\(i)"
            let part = await PartMeshFactory.entity(step.partId)
            wrap.addChild(part)
            wrap.position = Self.slot(k, radial: radial)
            if radial {
                let plinth = ModelEntity(mesh: .generateBox(width: 0.5, height: 0.9, depth: 0.5, cornerRadius: 0.04),
                                         materials: [PartMeshFactory.paint(0x161C2E, rough: 0.7)])
                plinth.position = wrap.position - [0, 0.45, 0]
                rack.addChild(plinth)
            }
            let b = part.visualBounds(relativeTo: wrap)
            if !b.isEmpty {
                let ext = simd_max(b.extents, [0.15, 0.15, 0.15])
                wrap.components.set(CollisionComponent(shapes: [.generateBox(size: ext).offsetBy(translation: b.center)]))
            }
            wrap.components.set(InputTargetComponent())
            wrap.components.set(HoverEffectComponent())
            if i == index {
                // Grab hint: ring under the part on the rack.
                let hint = ModelEntity(mesh: .generateCylinder(height: 0.01, radius: 0.45),
                                       materials: [PartMeshFactory.unlit(Self.telemetry, alpha: 0.45)])
                hint.position = [0, 0.005, 0]
                wrap.addChild(hint)
            }
            homes[i] = wrap.transform
            rack.addChild(wrap)
        }
        guard index < plan.count else { return }
        let step = plan.steps[index]
        let place = plan.placement(of: step)
        for a in place.angles {
            let g = await PartMeshFactory.entity(step.partId)
            Self.tint(g, Self.telemetry, alpha: 0.28)
            g.transform = Self.local(place, angle: a, radial: place.radius > 0)
            ghost.addChild(g)
        }
        let dia = Float(step.instance.definition.diameter)
        let r = ModelEntity(mesh: .generateCylinder(height: 0.015, radius: place.radius > 0 ? Float(place.radius) + 0.25 : dia / 2 + 0.12),
                            materials: [PartMeshFactory.unlit(Self.telemetry, alpha: 0.7)])
        r.position = [0, Float(place.y), 0]
        r.name = "ring"
        ghost.addChild(r)
        ring = r
        if index < 2 { addPathHint(from: homes[index]?.translation ?? .zero, to: craftHolder, place: place) }
        breathe()
    }

    static func local(_ p: (y: Double, radius: Double, angles: [Double]), angle: Double, radial: Bool) -> Transform {
        let rot = simd_quatf(angle: Float(-angle), axis: [0, 1, 0])
        let pos: SIMD3<Float> = radial ? rot.act([Float(p.radius), Float(p.y), 0]) : [0, Float(p.y), 0]
        return Transform(scale: .one, rotation: radial ? rot : simd_quatf(angle: 0, axis: [0, 1, 0]), translation: pos)
    }

    /// World transform of the first copy of the current step.
    func target(plan: AssemblyPlan, index: Int, craftHolder: Entity) -> Transform? {
        guard index < plan.count else { return nil }
        let p = plan.placement(of: plan.steps[index])
        let local = Self.local(p, angle: p.angles[0], radial: p.radius > 0)
        return Transform(matrix: craftHolder.transformMatrix(relativeTo: nil) * local.matrix)
    }

    static func tint(_ e: Entity, _ hex: UInt32, alpha: CGFloat) {
        if var m = e.components[ModelComponent.self] {
            m.materials = m.materials.map { _ in PartMeshFactory.unlit(hex, alpha: alpha) }
            e.components.set(m)
        }
        for c in e.children { tint(c, hex, alpha: alpha) }
    }

    private func addPathHint(from: SIMD3<Float>, to holder: Entity, place: (y: Double, radius: Double, angles: [Double])) {
        let end = holder.convert(position: [0, Float(place.y) + 0.6, 0], to: nil)
        let start = from + [0, 1.2, 0]
        let parent = ghost.parent ?? holder
        for k in 1..<12 {
            let t = Float(k) / 12
            var p = simd_mix(start, end, [t, t, t])
            p.y += sin(t * .pi) * 0.8
            let dot = ModelEntity(mesh: .generateSphere(radius: 0.025), materials: [PartMeshFactory.unlit(Self.trajectory, alpha: 0.8)])
            dot.position = parent.convert(position: p, from: nil)
            dot.scale = .init(repeating: 1 / max(holder.scale.x, 0.01))
            ghost.addChild(dot)
            dot.setPosition(p, relativeTo: nil)
        }
    }

    /// Slow 1.5 s breath on the ghost (skipped with Reduce Motion).
    private func breathe() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        Task { @MainActor [weak self] in
            var up = true
            while let self, self.ghost.parent != nil, !self.ghost.children.isEmpty {
                for c in self.ghost.children where c.name != "ring" {
                    if var op = c.components[OpacityComponent.self] { op.opacity = up ? 1 : 0.55; c.components.set(op) }
                    else { c.components.set(OpacityComponent(opacity: 0.8)) }
                }
                up.toggle()
                try? await Task.sleep(for: .milliseconds(750))
            }
        }
    }

    func setRing(_ hex: UInt32) {
        guard var m = ring?.components[ModelComponent.self] else { return }
        m.materials = [PartMeshFactory.unlit(hex, alpha: 0.85)]
        ring?.components.set(m)
    }

    // MARK: Manual

    static func rackIndex(of e: Entity) -> Int? {
        var cur: Entity? = e
        while let c = cur {
            if c.name.hasPrefix("rack-"), let i = Int(c.name.dropFirst(5)) { return i }
            cur = c.parent
        }
        return nil
    }

    func entity(_ i: Int) -> Entity? { rack.children.first { $0.name == "rack-\(i)" } }

    enum DragResult { case free, snapped, wrong }

    /// Moves a held part toward the hand. Heavy parts trail the hand. Returns snap state for the ring.
    func drag(_ i: Int, hand: SIMD3<Float>, current: Int, target: Transform?, heavy: Bool) -> DragResult {
        guard let e = entity(i) else { return .free }
        let pos = e.position(relativeTo: nil)
        if grabOffset == nil { grabOffset = pos - hand }
        let want = hand + (grabOffset ?? .zero)
        let next = heavy ? pos + (want - pos) * 0.35 : want
        guard let target else { e.setPosition(next, relativeTo: nil); return .free }
        let radius = max(0.6 * target.scale.x, 0.12)
        let near = simd_distance(next, target.translation) < radius
        if near && i == current {
            e.move(to: target, relativeTo: nil, duration: 0.12)
            snapped = true
            setRing(Self.telemetry)
            return .snapped
        }
        snapped = false
        e.setPosition(next, relativeTo: nil)
        setRing(near ? Self.ignition : Self.telemetry)
        return near ? .wrong : .free
    }

    func release(_ i: Int) {
        grabOffset = nil
        if !snapped, let e = entity(i), let home = homes[i] {
            e.move(to: home, relativeTo: rack, duration: 0.4, timingFunction: .easeInOut)
        }
    }

    // MARK: Watch

    /// Lift, arc over and lower the current part into place. Total 2.3 s at 1x.
    func autoPlace(_ i: Int, target: Transform, speed: Double) async {
        guard let e = entity(i) else { return }
        let s = max(speed, 0.25)
        if UIAccessibility.isReduceMotionEnabled {
            e.transform = Transform(matrix: e.parent.map { $0.transformMatrix(relativeTo: nil).inverse * target.matrix } ?? target.matrix)
            try? await Task.sleep(for: .seconds(0.4 / s))
            return
        }
        var lift = Transform(matrix: e.transformMatrix(relativeTo: nil))
        lift.translation.y += 0.6
        await step(e, lift, 0.6 / s)
        var above = target
        above.translation.y += 0.5 * max(target.scale.x, 0.1) + 0.1
        await step(e, above, 1.2 / s)
        await step(e, target, 0.5 / s)
    }

    private func step(_ e: Entity, _ t: Transform, _ d: Double) async {
        e.move(to: t, relativeTo: nil, duration: d, timingFunction: .easeInOut)
        try? await Task.sleep(for: .seconds(d))
    }

    /// Cyan flash expanding at the node.
    func flash(at world: Transform, in root: Entity) {
        let f = ModelEntity(mesh: .generateCylinder(height: 0.01, radius: 0.5 * max(world.scale.x, 0.05)),
                            materials: [PartMeshFactory.unlit(Self.telemetry, alpha: 0.9)])
        f.setPosition(world.translation, relativeTo: nil)
        root.addChild(f)
        f.setPosition(world.translation, relativeTo: nil)
        var big = f.transform; big.scale = [1.5, 1, 1.5]
        f.move(to: big, relativeTo: f.parent, duration: 0.25)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            f.removeFromParent()
        }
    }
}
