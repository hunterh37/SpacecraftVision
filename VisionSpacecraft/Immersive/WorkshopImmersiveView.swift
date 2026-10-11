import SwiftUI
import RealityKit
import RealKit
import RealLibrary
import SpacecraftCore
import TaskGuideCore

/// Life-size hangar (specs/02): 30 x 20 x 12 m shell, open door to the sky, RealityHD clutter props,
/// the craft at 1:1 on the floor 3 m ahead, and the live stat board beside it.
struct WorkshopImmersiveView: View {
    @Environment(AppModel.self) private var model
    @State private var craftHolder = Entity()
    @State private var guidanceRing = Entity()
    @State private var env: RealEnvironment?
    @State private var skyHolder = Entity()
    @State private var stage = AssemblyStage()
    @State private var held: Int?
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
            // Base: RealityHD "aerospace-hangar" turned 180 deg so its gantry bay sits behind the viewer and the
            // build square 3 m ahead stays clear. Fallback: the procedural shell plus loose clutter props.
            let hangar = try? await RealityHD.scene("aerospace-hangar", seed: 1)
            if let hangar {
                hangar.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
                root.addChild(hangar)
            } else {
                root.addChild(await Self.hangarShell())
            }
            root.addChild(looseParts)
            await spawnLooseParts()
            craftHolder.position = [0, 0, -3]
            root.addChild(craftHolder)
            guidanceRing.name = "taskGuideCraftRing"
            guidanceRing.isEnabled = false
            root.addChild(guidanceRing)
            craftHolder.addChild(stage.ghost)
            root.addChild(stage.rack)
            if let card = attachments.entity(for: "assembly") {
                card.position = [-1.3, 1.25, -1.6]
                card.orientation = simd_quatf(angle: 0.45, axis: [0, 1, 0])
                root.addChild(card)
            }
            if let board = attachments.entity(for: "board") {
                board.position = [1.7, 1.45, -2.6]
                board.orientation = simd_quatf(angle: -0.35, axis: [0, 1, 0])
                root.addChild(board)
            }
            if let panel = attachments.entity(for: "taskGuide") {
                // Right of the pad, clear of the assembly card and rack on the left.
                panel.position = [2.3, 1.3, -1.3]
                panel.orientation = simd_quatf(angle: -0.9, axis: [0, 1, 0])
                root.addChild(panel)
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
            for (id, p, yaw, seed) in props where hangar == nil {
                if let e = try? await RealityHD.entity(id, seed: seed) {
                    e.position = p
                    e.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
                    root.addChild(e)
                }
            }
            env?.illuminate(root)
            model.loadingSpace = nil
        } update: { _, attachments in
            if let panel = attachments.entity(for: "taskGuide") {
                panel.isEnabled = model.taskGuideVisible && model.taskGuide.state.sessionPhase != .exited
            }
            updateCraftGuidanceRing()
        } attachments: {
            Attachment(id: "board") {
                StatBoardView()
                    .environment(model)
            }
            Attachment(id: "taskGuide") {
                WorkshopTaskGuidePanel()
                    .environment(model)
            }
            Attachment(id: "assembly") {
                AssemblyCardView()
                    .environment(model)
            }
        }
        .gesture(DragGesture(minimumDistance: 0.01, coordinateSpace: .local).targetedToAnyEntity()
            .onChanged { v in
                let a = model.assembly
                guard a.active, let plan = a.plan, let i = AssemblyStage.rackIndex(of: v.entity) else { return }
                // Grabbing a rack part during Watch build or Show me hands control to the player.
                if a.mode == .watch || a.showMe { a.takeOver() }
                held = i
                let hand = v.convert(v.location3D, from: .local, to: .scene)
                let heavy = plan.steps[i].instance.definition.length > 2
                let r = stage.drag(i, hand: hand, current: a.index, target: stage.target(plan: plan, index: a.index, craftHolder: craftHolder),
                                   heavy: heavy)
                if r == .wrong, let cur = a.current {
                    a.warning = "\(cur.instance.definition.displayName) goes here. Put the \(plan.steps[i].instance.definition.displayName) back."
                } else if r == .snapped { a.warning = nil }
            }
            .onEnded { _ in
                guard let i = held else { return }
                held = nil
                let a = model.assembly
                if stage.snapped, i == a.index, let plan = a.plan, let t = stage.target(plan: plan, index: i, craftHolder: craftHolder) {
                    stage.flash(at: t, in: craftHolder.parent ?? craftHolder)
                    a.lock(model)
                } else {
                    stage.release(i)
                }
            })
        .task(id: StageKey(index: model.assembly.index, mode: model.assembly.mode, plan: model.assembly.plan?.target.id,
                           table: model.workshopTabletop)) {
            let a = model.assembly
            await stage.rebuild(plan: a.plan, index: a.index, showRack: a.active, craftHolder: craftHolder)
            env?.illuminate(stage.rack)
        }
        .task(id: PlayKey(index: model.assembly.index, playing: model.assembly.playing, showMe: model.assembly.showMe,
                          mode: model.assembly.mode)) {
            let a = model.assembly
            guard (a.mode == .watch && a.playing) || (a.mode == .manual && a.showMe), let plan = a.plan, a.index < plan.count else { return }
            // Let the rack rebuild for this index first.
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let t = stage.target(plan: plan, index: a.index, craftHolder: craftHolder) else { return }
            await stage.autoPlace(a.index, target: t, speed: a.speed)
            guard !Task.isCancelled else { return }
            stage.flash(at: t, in: craftHolder.parent ?? craftHolder)
            a.showMe = false
            a.lock(model)
            try? await Task.sleep(for: .seconds(0.3 / a.speed))
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
            craftHolder.children.filter { $0.name == "craft" }.forEach { $0.removeFromParent() }
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
            updateCraftGuidanceRing()
        }
        .task(id: model.skyStyle) { updateSky() }
        .onChange(of: model.taskGuideTargetID) { _, _ in updateCraftGuidanceRing() }
        .onChange(of: model.taskGuideVisible) { _, visible in
            if !visible { clearCraftGuidanceRing() }
            else { updateCraftGuidanceRing() }
        }
        .onAppear { model.syncTaskGuideSnapshot() }
        .onDisappear { clearCraftGuidanceRing() }
    }

    struct CraftKey: Hashable { var craft: CraftDesign; var sel: UUID?; var table: Bool }
    struct StageKey: Hashable { var index: Int; var mode: AssemblyModel.Mode; var plan: UUID?; var table: Bool }
    struct PlayKey: Hashable { var index: Int; var playing: Bool; var showMe: Bool; var mode: AssemblyModel.Mode }

    private func updateSky() {
        skyHolder.children.removeAll()
        if let sky = SkyBackdrop.make(model.skyStyle, timeOfDay: .afternoon, radius: 300) { skyHolder.addChild(sky) }
        SceneLighting.update(sun: sun, style: model.skyStyle, timeOfDay: .afternoon)
    }

    private func clearCraftGuidanceRing() {
        guidanceRing.isEnabled = false
        guidanceRing.children.removeAll()
    }

    private func updateCraftGuidanceRing() {
        let active = model.taskGuideVisible
            && (model.taskGuideTargetID == .craftAssembly || model.taskGuideTargetID == .partsStack)
        guidanceRing.position = craftHolder.position
        guidanceRing.scale = craftHolder.scale
        guard active else {
            clearCraftGuidanceRing()
            return
        }
        guidanceRing.isEnabled = true
        guidanceRing.children.removeAll()
        let height = Float(max(model.craft.height, 0.5))
        let radius = Float(max(model.craft.stack.map { $0.definition.diameter }.max() ?? 0.6, 0.4) / 2 + 0.18)
        let ring = ModelEntity(
            mesh: .generateCylinder(height: 0.03, radius: radius),
            materials: [PartMeshFactory.unlit(0x58C8FF, alpha: 0.45)]
        )
        ring.position = [0, 0.02, 0]
        let column = ModelEntity(
            mesh: .generateCylinder(height: height + 0.4, radius: 0.04),
            materials: [PartMeshFactory.unlit(0x58C8FF, alpha: 0.28)]
        )
        column.position = [0, (height + 0.4) / 2, 0]
        guidanceRing.addChild(ring)
        guidanceRing.addChild(column)
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
