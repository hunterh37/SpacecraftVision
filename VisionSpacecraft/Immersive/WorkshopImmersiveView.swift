import SwiftUI
import RealityKit
import RealKit
import RealLibrary
import SpacecraftCore

/// Life-size hangar (specs/02): 30 x 20 x 12 m shell, open door to the sky, RealityHD clutter props,
/// the craft at 1:1 on the floor 3 m ahead, and the live stat board beside it.
struct WorkshopImmersiveView: View {
    @Environment(AppModel.self) private var model
    @State private var craftHolder = Entity()
    @State private var env: RealEnvironment?
    @State private var skyHolder = Entity()
    @State private var sun = Entity()
    @State private var looseParts = Entity()
    /// Loose parts on stands; drag one onto the build square to add it to the craft.
    static let partStands: [(String, SIMD3<Float>)] = [
        ("fuel-tank-m", [-5.0, 0.15, -4.2]), ("engine-liquid-small", [-5.0, 0.15, -2.8]),
        ("nose-cone", [-6.4, 0.15, -4.2]), ("fin-trapezoid", [-6.4, 0.15, -2.8]), ("parachute", [-5.7, 0.15, -1.6]),
    ]

    var body: some View {
        RealityView { content, attachments in
            let root = Entity()
            content.add(root)
            if let env = try? RealEnvironment({ var s = SunSky.afternoon; s.fogDensity = 0.0005; return s }(), skybox: true,
                                              skyboxRadius: 400) {
                content.add(env.root)
                self.env = env
            }
            content.add(skyHolder)
            content.add(sun)
            updateSky()
            root.addChild(await Self.hangarShell())
            root.addChild(looseParts)
            await spawnLooseParts()
            craftHolder.position = [0, 0, -3]
            root.addChild(craftHolder)
            if let board = attachments.entity(for: "board") {
                board.position = [1.7, 1.45, -2.6]
                board.orientation = simd_quatf(angle: -0.35, axis: [0, 1, 0])
                root.addChild(board)
            }
            // RealityHD clutter (existing catalog assets).
            let props: [(String, SIMD3<Float>, Float, UInt64)] = [
                ("oil-drum", [-4.5, 0, -6], 0, 1), ("oil-drum", [-4.0, 0, -6.6], 0.6, 2), ("oil-drum", [-5.1, 0, -6.4], 1.2, 3),
                ("cable-spool", [5.5, 0, -7], 0.3, 1), ("barrel", [-6, 0, -2], 0, 4), ("workbench", [4.5, 0, -3.2], -1.57, 1),
                ("tool-chest", [5.6, 0, -1.4], -1.57, 1), ("sawhorse", [-3.5, 0, -2.5], 0.4, 1), ("fire-extinguisher", [-7.5, 0, 0.5], 0, 1),
                ("pallet", [3, 0, -8], 0.2, 1), ("traffic-cone", [3.4, 0, 0.4], 0, 1), ("traffic-cone", [-3.4, 0, 0.4], 0, 2),
                ("pegboard-wall", [14.85, 1.0, -3.2], -1.57, 1), ("lumber-rack", [14.7, 0, -9], -1.57, 1),
                ("shop-vac", [6.4, 0, -2.2], 0.4, 1), ("first-aid-kit", [14.85, 1.4, 0.8], -1.57, 1),
                ("shipping-container", [-11, 0, -12], 1.57, 1), ("cordless-drill", [4.2, 0.95, -3.2], 0.5, 1),
                ("tape-measure", [4.9, 0.95, -3.1], 0, 1), ("job-ticket", [4.6, 0.95, -3.35], 0.2, 1),
                ("safety-glasses", [5.0, 0.95, -3.3], 1, 1), ("utility-cabinet", [-14.6, 0, -6], 1.57, 1),
                ("pallet", [-5.7, 0, -3.5], 0, 2), ("pallet", [-5.7, 0, -2.4], 0, 3),
            ]
            for (id, p, yaw, seed) in props {
                if let e = try? await RealityHD.entity(id, seed: seed) {
                    e.position = p
                    e.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
                    root.addChild(e)
                }
            }
            env?.illuminate(root)
        } update: { _, _ in
        } attachments: {
            Attachment(id: "board") {
                StatBoardView()
                    .environment(model)
            }
        }
        .gesture(DragGesture().targetedToEntity(where: .has(LoosePartComponent.self))
            .onChanged { v in
                guard let parent = v.entity.parent else { return }
                v.entity.position = v.convert(v.location3D, from: .local, to: parent)
            }
            .onEnded { v in
                guard let lp = v.entity.components[LoosePartComponent.self] else { return }
                let p = v.entity.position(relativeTo: nil)
                if abs(p.x) < 3, p.z > -6, p.z < 0 { model.addPart(lp.partId) }
                v.entity.move(to: Transform(scale: v.entity.scale, rotation: v.entity.orientation, translation: lp.home),
                              relativeTo: v.entity.parent, duration: 0.4)
            })
        .task(id: CraftKey(craft: model.craft, sel: model.selectedStackPart, table: model.workshopTabletop)) {
            let e = await CraftBuilder.build(model.craft, markers: true, highlight: model.selectedStackPart)
            craftHolder.children.removeAll()
            craftHolder.addChild(e)
            if model.workshopTabletop {
                // 1:20 model on the workbench.
                craftHolder.position = [4.5, 0.95, -3.2]
                craftHolder.scale = .init(repeating: 0.05)
            } else {
                craftHolder.position = [0, 0, -3]
                craftHolder.scale = .one
            }
            env?.illuminate(craftHolder)
        }
        .task(id: model.skyStyle) { updateSky() }
    }

    struct CraftKey: Hashable { var craft: CraftDesign; var sel: UUID?; var table: Bool }

    private func updateSky() {
        skyHolder.children.removeAll()
        if let sky = SkyBackdrop.make(model.skyStyle, timeOfDay: .afternoon, radius: 300) { skyHolder.addChild(sky) }
        SceneLighting.update(sun: sun, style: model.skyStyle, timeOfDay: .afternoon)
    }

    private func spawnLooseParts() async {
        looseParts.children.removeAll()
        for (id, home) in Self.partStands {
            let e = await PartMeshFactory.entity(id)
            let holder = Entity()
            holder.addChild(e)
            let b = e.visualBounds(relativeTo: holder)
            let fit = min(1, 0.9 / max(b.extents.x, b.extents.y, b.extents.z, 0.01))
            holder.scale = .init(repeating: fit)
            holder.position = home
            holder.components.set(CollisionComponent(shapes: [.generateBox(size: b.extents).offsetBy(translation: b.center)]))
            holder.components.set(InputTargetComponent())
            holder.components.set(HoverEffectComponent())
            holder.components.set(LoosePartComponent(partId: id, home: home))
            looseParts.addChild(holder)
        }
        env?.illuminate(looseParts)
    }

    /// Plane with UVs in meters / tile so RealityHD tiling materials keep real-world scale.
    static func tiledPlane(_ a: Float, _ b: Float, tile: Float) -> MeshResource {
        var d = MeshDescriptor()
        d.positions = MeshBuffers.Positions([[-a/2, 0, -b/2], [a/2, 0, -b/2], [a/2, 0, b/2], [-a/2, 0, b/2]])
        d.normals = MeshBuffers.Normals([[0, 1, 0], [0, 1, 0], [0, 1, 0], [0, 1, 0]])
        d.textureCoordinates = MeshBuffers.TextureCoordinates([[0, 0], [a/tile, 0], [a/tile, b/tile], [0, b/tile]])
        d.primitives = .triangles([0, 2, 1, 0, 3, 2])
        return (try? MeshResource.generate(from: [d])) ?? .generatePlane(width: a, depth: b)
    }

    static func hangarShell() async -> Entity {
        let shell = Entity()
        let lib = RealMaterialCache.shared
        let concrete = await lib.materialAsync("concrete.smooth")
        let wall = await lib.materialAsync("metal.galvanized-aged")
        let roof = await lib.materialAsync("metal.galvanized")
        let w: Float = 30, d: Float = 20, h: Float = 12
        // Textured inner faces: plane rotated so +y normal faces into the hangar.
        func face(_ a: Float, _ b: Float, _ p: SIMD3<Float>, _ rot: simd_quatf, _ m: any RealityKit.Material, tile: Float = 2) {
            let e = ModelEntity(mesh: tiledPlane(a, b, tile: tile), materials: [m])
            e.position = p; e.orientation = rot
            shell.addChild(e)
        }
        let cz = -d / 2 + 4
        face(w, d, [0, 0.001, cz], simd_quatf(angle: 0, axis: [1, 0, 0]), concrete, tile: 3)
        face(w, h, [0, h / 2, 3.89], simd_quatf(angle: -.pi / 2, axis: [1, 0, 0]), wall)
        face(h, d, [-w / 2 + 0.11, h / 2, cz], simd_quatf(angle: -.pi / 2, axis: [0, 0, 1]), wall)
        face(h, d, [w / 2 - 0.11, h / 2, cz], simd_quatf(angle: .pi / 2, axis: [0, 0, 1]), wall)
        face(w, d, [0, h - 0.16, cz], simd_quatf(angle: .pi, axis: [1, 0, 0]), roof, tile: 3)
        // Roof trusses.
        let steel = await lib.materialAsync("metal.steel")
        for z in stride(from: cz - d / 2 + 2, through: cz + d / 2 - 2, by: 4) as StrideThrough<Float> {
            let t = ModelEntity(mesh: .generateBox(size: [w, 0.4, 0.25]), materials: [steel])
            t.position = [0, h - 0.6, z]
            shell.addChild(t)
        }
        func box(_ size: SIMD3<Float>, _ p: SIMD3<Float>, _ m: any RealityKit.Material) {
            let e = ModelEntity(mesh: .generateBox(size: size), materials: [m])
            e.position = p
            shell.addChild(e)
        }
        // Floor (top at y = 0), back wall behind the player, side walls, roof; front wall has the door opening.
        let front: Float = -d + 4
        box([9, h, 0.2], [-10.5, h / 2, front], wall)
        box([9, h, 0.2], [10.5, h / 2, front], wall)
        box([12, 3, 0.2], [0, h - 1.5, front], wall)
        // Floor markings: build square.
        box([6, 0.005, 0.08], [0, 0.003, -6], PartMeshFactory.unlit(0xF2C230))
        box([6, 0.005, 0.08], [0, 0.003, 0], PartMeshFactory.unlit(0xF2C230))
        box([0.08, 0.005, 6], [-3, 0.003, -3], PartMeshFactory.unlit(0xF2C230))
        box([0.08, 0.005, 6], [3, 0.003, -3], PartMeshFactory.unlit(0xF2C230))
        // High-bay lamps.
        for x in [-8, 0, 8] as [Float] {
            for z in [-12, -4] as [Float] {
                let lamp = ModelEntity(mesh: .generateCylinder(height: 0.2, radius: 0.4), materials: [PartMeshFactory.unlit(0xFFF4DC)])
                lamp.position = [x, h - 0.6, z]
                let light = PointLightComponent(color: .init(red: 1, green: 0.95, blue: 0.86, alpha: 1), intensity: 60_000,
                                                attenuationRadius: 18)
                lamp.components.set(light)
                shell.addChild(lamp)
            }
        }
        return shell
    }
}

struct LoosePartComponent: Component { var partId: String; var home: SIMD3<Float> }
