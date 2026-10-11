import RealityKit
import SpacecraftCore

enum SkyStyle: String, CaseIterable, Identifiable {
    case mission, morning, sunset

    var id: String { rawValue }
    var title: String {
        switch self {
        case .mission: "Match mission"
        case .morning: "Morning"
        case .sunset: "Sunset"
        }
    }

    func imageName(for timeOfDay: TimeOfDay) -> String {
        switch self {
        case .morning: "SkyMorning"
        case .sunset: "SkySunset"
        case .mission: timeOfDay == .morning ? "SkyMorning" : "SkySunset"
        }
    }
}

@MainActor
enum SkyBackdrop {
    /// The panoramas are equirectangular. Inverting the sphere makes its textured face visible from inside.
    static func make(_ style: SkyStyle, timeOfDay: TimeOfDay, radius: Float) -> ModelEntity? {
        guard let texture = try? TextureResource.load(named: style.imageName(for: timeOfDay), in: .main) else { return nil }
        var material = UnlitMaterial(color: .white)
        material.color = .init(tint: .white, texture: .init(texture))
        let sphere = ModelEntity(mesh: .generateSphere(radius: radius), materials: [material])
        sphere.scale = [-1, 1, 1]
        return sphere
    }
}
