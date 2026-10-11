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

    var body: some View {
        RealityView { content, attachments in
            let root = Entity()
            content.add(root)
            if let env = try? RealEnvironment({ var s = SunSky.afternoon; s.fogDensity = 0.0005; return s }(), skybox: true,
                                              skyboxRadius: 400) {
                content.add(env.root)
                self.env = env
            }
            root.addChild(Self.hangarShell())
            craftHolder.position = [0, 0, -3]
            root.addChild(craftHolder)

            // Sibling of the craft holder so CraftBuilder rebuilds do not remove it.
            guidanceRing.name = "taskGuideCraftRing"
            guidanceRing.isEnabled = false
            root.addChild(guidanceRing)

            if let board = attachments.entity(for: "board") {
                board.position = [1.7, 1.45, -2.6]
                board.orientation = simd_quatf(angle: -0.35, axis: [0, 1, 0])
                root.addChild(board)
            }
            if let panel = attachments.entity(for: "taskGuide") {
                // Beside the craft, opposite the stats board — not over the rocket.
                panel.position = [-1.85, 1.35, -2.4]
                panel.orientation = simd_quatf(angle: 0.35, axis: [0, 1, 0])
                root.addChild(panel)
            }
            // RealityHD clutter (existing catalog assets).
            let props: [(String, SIMD3<Float>, Float, UInt64)] = [
                ("oil-drum", [-4.5, 0, -6], 0, 1), ("oil-drum", [-4.0, 0, -6.6], 0.6, 2), ("oil-drum", [-5.1, 0, -6.4], 1.2, 3),
                ("cable-spool", [5.5, 0, -7], 0.3, 1), ("barrel", [-6, 0, -2], 0, 4), ("workbench", [4.5, 0, -3.2], -1.57, 1),
                ("tool-chest", [5.6, 0, -1.4], -1.57, 1), ("sawhorse", [-3.5, 0, -2.5], 0.4, 1), ("fire-extinguisher", [-7.5, 0, 0.5], 0, 1),
                ("pallet", [3, 0, -8], 0.2, 1), ("traffic-cone", [1.2, 0, -5.5], 0, 1), ("traffic-cone", [-1.2, 0, -5.5], 0, 2),
            ]
            for (id, p, yaw, seed) in props {
                if let e = try? await RealityHD.entity(id, seed: seed) {
                    e.position = p
                    e.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
                    root.addChild(e)
                }
            }
            env?.illuminate(root)
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
        }
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
            updateCraftGuidanceRing()
        }
        .onChange(of: model.taskGuideTargetID) { _, _ in updateCraftGuidanceRing() }
        .onChange(of: model.taskGuideVisible) { _, _ in updateCraftGuidanceRing() }
        .onAppear { model.syncTaskGuideSnapshot() }
    }

    struct CraftKey: Hashable { var craft: CraftDesign; var sel: UUID?; var table: Bool }

    private func updateCraftGuidanceRing() {
        let active = model.taskGuideVisible && model.taskGuideTargetID == .craftAssembly
        guidanceRing.position = craftHolder.position
        guidanceRing.scale = craftHolder.scale
        guidanceRing.isEnabled = active
        guard active else {
            guidanceRing.children.removeAll()
            return
        }
        guidanceRing.children.removeAll()
        let height = Float(max(model.craft.height, 0.5))
        let radius = Float(max(model.craft.stack.map { $0.definition.diameter }.max() ?? 0.6, 0.4) / 2 + 0.18)
        let ring = ModelEntity(
            mesh: .generateCylinder(height: 0.03, radius: radius),
            materials: [PartMeshFactory.unlit(0x58C8FF, alpha: 0.55)]
        )
        ring.position = [0, 0.02, 0]
        ring.name = "taskGuidePadRing"
        let column = ModelEntity(
            mesh: .generateCylinder(height: height + 0.4, radius: 0.04),
            materials: [PartMeshFactory.unlit(0x58C8FF, alpha: 0.35)]
        )
        column.position = [0, (height + 0.4) / 2, 0]
        column.name = "taskGuideColumn"
        guidanceRing.addChild(ring)
        guidanceRing.addChild(column)
    }

    static func hangarShell() -> Entity {
        let shell = Entity()
        let concrete = PartMeshFactory.paint(0x7E7C76, rough: 0.85)
        let wall = PartMeshFactory.metal(0xB8BCC0, rough: 0.6, metallic: 0.5)
        let w: Float = 30, d: Float = 20, h: Float = 12
        func box(_ size: SIMD3<Float>, _ p: SIMD3<Float>, _ m: some RealityKit.Material) {
            let e = ModelEntity(mesh: .generateBox(size: size), materials: [m])
            e.position = p
            shell.addChild(e)
        }
        // Floor (top at y = 0), back wall behind the player, side walls, roof; front wall has the door opening.
        box([w, 0.1, d], [0, -0.05, -d / 2 + 4], concrete)
        box([w, h, 0.2], [0, h / 2, 4], wall)
        box([0.2, h, d], [-w / 2, h / 2, -d / 2 + 4], wall)
        box([0.2, h, d], [w / 2, h / 2, -d / 2 + 4], wall)
        box([w, 0.3, d], [0, h, -d / 2 + 4], wall)
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
