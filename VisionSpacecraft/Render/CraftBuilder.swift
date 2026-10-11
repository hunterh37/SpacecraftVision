import Foundation
import RealityKit
import SpacecraftCore

/// Assembles a craft entity from a design: stack bottom at y = 0, axis +y, 1:1 metres.
@MainActor
enum CraftBuilder {
    static func build(_ craft: CraftDesign, markers: Bool = false, highlight: UUID? = nil) async -> Entity {
        let root = Entity()
        root.name = "craft"
        let spans = craft.stackSpans
        var spanOf: [UUID: (bottom: Double, top: Double, dia: Double)] = [:]
        for (i, p) in craft.stack.enumerated() {
            let e = await PartMeshFactory.entity(p.partId)
            e.components.set(PartTagComponent(partId: p.partId))
            e.position = [0, Float(spans[i].bottom), 0]
            e.name = p.id.uuidString
            if p.id == highlight {
                let ring = ModelEntity(mesh: .generateCylinder(height: 0.02, radius: Float(p.definition.diameter / 2 + 0.06)),
                                       materials: [PartMeshFactory.unlit(0x58C8FF, alpha: 0.8)])
                ring.position = [0, Float(p.definition.length / 2), 0]
                e.addChild(ring)
            }
            root.addChild(e)
            spanOf[p.id] = (spans[i].bottom, spans[i].top, p.definition.diameter)
        }
        var slot: [UUID: Int] = [:]
        let aircraft = craft.radial.contains { $0.partId == "wing-section" }
        for r in craft.radial {
            guard let pid = r.parentId, let span = spanOf[pid] else { continue }
            let count = max(1, r.count)
            let base = slot[pid, default: 0]
            for k in 0..<count {
                let e = await PartMeshFactory.entity(r.partId)
                e.components.set(PartTagComponent(partId: r.partId))
                let ang: Float
                if aircraft && ["wing-section", "elevon"].contains(r.partId) { ang = Float(k) * .pi }   // local x: wings level
                else if aircraft && r.partId == "fin-trapezoid" && count == 1 { ang = .pi / 2 }        // local z: vertical fin
                else if count > 1 { ang = Float(k) / Float(count) * 2 * .pi + .pi / 4 } else { ang = Float(base) * 1.1 + 0.4 }
                let rr = Float(span.dia / 2)
                let y: Float = r.partId == "fin-trapezoid" || r.partId == "engine-solid-small" ? Float(span.bottom) : Float((span.bottom + span.top) / 2) - 0.1
                let rot = simd_quatf(angle: -ang, axis: [0, 1, 0])
                e.orientation = rot
                e.position = rot.act([rr, y, 0])
                if PartMeshFactory.isPlaceholder(e), r.partId != "fin-trapezoid" {
                    // Placeholders stand 5 cm off the skin; RealityHD parts are mounted on it (PartMeshFactory.mounted).
                    e.position = rot.act([rr + 0.05, y, 0])
                }
                root.addChild(e)
            }
            if count == 1 { slot[pid] = base + 1 }
        }
        if markers {
            let s = craft.stats()
            let com = ModelEntity(mesh: .generateSphere(radius: 0.12), materials: [PartMeshFactory.unlit(0xF2C230)])
            com.position = [0.95, Float(s.centerOfMass), 0.0]
            com.name = "com"
            root.addChild(com)
            if let cot = s.centerOfThrust {
                let m = ModelEntity(mesh: .generateSphere(radius: 0.1), materials: [PartMeshFactory.unlit(0xC8302C)])
                m.position = [0.95, Float(cot), 0]
                m.name = "cot"
                root.addChild(m)
            }
        }
        return root
    }
}
