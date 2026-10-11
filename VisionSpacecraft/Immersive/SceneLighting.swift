import RealityKit
import UIKit
import SpacecraftCore

@MainActor
enum SceneLighting {
    static func update(sun: Entity, fill: Entity? = nil, style: SkyStyle, timeOfDay: TimeOfDay) {
        let evening = style == .sunset || (style == .mission && timeOfDay != .morning)
        sun.components.set(DirectionalLightComponent(
            color: evening ? UIColor(red: 1, green: 0.72, blue: 0.48, alpha: 1) : UIColor(red: 1, green: 0.94, blue: 0.83, alpha: 1),
            intensity: evening ? 3_500 : 8_000
        ))
        sun.look(at: .zero, from: evening ? [100, 25, -60] : [80, 90, -70], relativeTo: nil)

        if let fill {
            fill.components.set(DirectionalLightComponent(
                color: UIColor(red: 0.55, green: 0.68, blue: 1, alpha: 1), intensity: evening ? 700 : 1_200
            ))
            fill.look(at: .zero, from: [-80, 45, 45], relativeTo: nil)
        }
    }
}
