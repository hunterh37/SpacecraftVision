import RealityKit
import UIKit
import RealKit
import RealLibrary
import SpacecraftCore

/// Course obstacles at their specs/15 sizes: RealityHD gap walls, pylons, balloons and debris rocks built from
/// configured assets, canyon walls from `canyon-wall` (procedural rock slabs while that id is missing).
/// Moving obstacles are posed from flight time by `update(time:)`.
@MainActor
final class CourseProps {
    let root = Entity()
    private var moving: [(Obstacle, Entity, SIMD3<Float>)] = []

    func build(_ course: Course) async {
        root.children.removeAll()
        moving.removeAll()
        for (i, o) in course.obstacles.enumerated() {
            let seed = UInt64(i + 1)
            let e: Entity
            var offset = SIMD3<Float>.zero
            switch o.kind {
            case .wall:
                let asset = GapWall().with {
                    $0.width = Float(o.length); $0.height = Float(o.height); $0.thickness = Float(o.thickness)
                    $0.slotWidth = Float(o.slotWidth ?? 0); $0.slotCenter = Float(o.slotCentre ?? 0)
                }
                e = (try? await RealityHD.entity(asset, seed: seed)) ?? Self.wallPlaceholder(o)
                if o.alongY { e.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0]) }
                offset = [0, -Float(o.height / 2), 0]
            case .pylon:
                let asset = Pylon().with { $0.radius = Float(o.radius); $0.height = Float(o.height) }
                e = (try? await RealityHD.entity(asset, seed: seed)) ?? Self.column(o, tint: 0xE2561B)
            case .pillar:
                let asset = CanyonWall().with { $0.kind = .pillar; $0.radius = Float(o.radius); $0.height = Float(o.height) }
                if let c = try? await RealityHD.entity(asset, seed: seed) {
                    e = c
                } else {
                    e = Self.column(o, tint: 0x8C6A4F)
                }
            case .balloon:
                let asset = ObstacleBalloon().with { $0.radius = Float(o.radius) }
                if let b = try? await RealityHD.entity(asset, seed: seed) {
                    // Origin at the anchor; centre the envelope on the obstacle position.
                    let top = b.visualBounds(relativeTo: nil).max.y
                    offset = [0, -(top - Float(o.radius)), 0]
                    e = b
                } else {
                    e = ModelEntity(mesh: .generateSphere(radius: Float(o.radius)), materials: [PartMeshFactory.paint(0xC8261E)])
                }
            case .debris:
                let asset = DebrisRock().with { $0.radius = Float(min(max(o.radius, 2), 8)) }
                if let d = try? await RealityHD.entity(asset, seed: seed) {
                    offset = -d.visualBounds(relativeTo: nil).center
                    // Spec radii below 2 m use the 2 m rock scaled down.
                    if o.radius < 2 { d.scale = .init(repeating: Float(o.radius / 2)) }
                    e = d
                } else {
                    e = ModelEntity(mesh: .generateSphere(radius: Float(o.radius)), materials: [PartMeshFactory.paint(0x6E6A64, rough: 0.95)])
                }
            }
            let holder = Entity()
            holder.name = o.id
            e.position = offset
            holder.addChild(e)
            holder.position = rk(o.position(at: 0))
            root.addChild(holder)
            if o.moving { moving.append((o, holder, .zero)) }
        }
        if let canyon = course.canyon { root.addChild(await Self.canyonWalls(canyon)) }
    }

    /// Pose balloons and debris at flight time t (debris spin about a seeded axis).
    func update(time t: Double) {
        for (o, e, _) in moving {
            e.position = rk(o.position(at: t))
            if o.kind == .debris {
                let axis = simd_normalize(SIMD3<Float>(Float(sin(o.centre.x)), 1, Float(cos(o.centre.y))))
                e.orientation = simd_quatf(angle: Float(o.spin * t), axis: axis)
            }
        }
    }

    static func wallPlaceholder(_ o: Obstacle) -> Entity {
        let root = Entity()
        let mat = PartMeshFactory.paint(0xE2561B)
        let L = Float(o.length), H = Float(o.height), T = Float(o.thickness)
        var spans: [(Float, Float)] = [(-L / 2, L / 2)]
        if let sc = o.slotCentre, let sw = o.slotWidth {
            spans = [(-L / 2, Float(sc - sw / 2)), (Float(sc + sw / 2), L / 2)].filter { $0.1 > $0.0 }
        }
        for (a, b) in spans {
            let m = ModelEntity(mesh: .generateBox(size: [b - a, H, T]), materials: [mat])
            m.position = [(a + b) / 2, H / 2, 0]
            root.addChild(m)
        }
        return root
    }

    static func column(_ o: Obstacle, tint: UInt32) -> Entity {
        let m = ModelEntity(mesh: .generateCylinder(height: Float(o.height), radius: Float(o.radius)),
                            materials: [PartMeshFactory.paint(tint, rough: 0.9)])
        m.position = [0, Float(o.height / 2), 0]
        return m
    }

    /// RealityHD `canyon-wall` faces along both sides of the centreline, faces toward the channel;
    /// procedural rock slabs when the asset is unavailable.
    static func canyonWalls(_ c: Canyon) async -> Entity {
        let root = Entity()
        root.name = "canyon"
        let pts = c.centreline
        for side in [1.0, -1.0] {
            // Offset polyline (right side +1), in RealityKit XZ (x east, z = -north).
            var line: [V2] = []
            for (i, p) in pts.enumerated() {
                let a = pts[max(0, i - 1)], b = pts[min(pts.count - 1, i + 1)]
                let d = b - a, l = max(simd_len(Vec3(d.x, d.y, 0)), 1e-6)
                let n = Vec3(d.y, -d.x, 0) / l
                let q = p + n * c.offset * side
                line.append(V2(Float(q.x), Float(-q.y)))
            }
            // The face looks toward the polyline's left normal: run forward on the right, backward on the left.
            if side < 0 { line.reverse() }
            let asset = CanyonWall().with { $0.kind = .face; $0.polyline = line; $0.height = Float(c.height) }
            if let e = try? await RealityHD.entity(asset, seed: side > 0 ? 51 : 52) {
                root.addChild(e)
            } else {
                root.addChild(slabs(c, side: side))
            }
        }
        return root
    }

    static func slabs(_ c: Canyon, side: Double) -> Entity {
        let root = Entity()
        let rock = PartMeshFactory.paint(0x9A6B4A, rough: 0.95)
        let H = Float(c.height)
        for (a, b) in zip(c.centreline, c.centreline.dropFirst()) {
            let d = b - a
            let len = Float(simd_len(Vec3(d.x, d.y, 0)))
            guard len > 0.1 else { continue }
            let n = Vec3(d.y, -d.x, 0) / Double(len)
            let heading = Float(atan2(d.x, d.y))
            let mid = (a + b) / 2 + n * (c.offset + 3) * side
            let m = ModelEntity(mesh: .generateBox(size: [6, H, len + 12]), materials: [rock])
            m.position = rk(Vec3(mid.x, mid.y, 0)) + [0, H / 2, 0]
            m.orientation = simd_quatf(angle: -heading, axis: [0, 1, 0])
            root.addChild(m)
        }
        return root
    }
}
