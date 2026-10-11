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
    private static var meshes: [Float: MeshResource] = [:]

    /// The supplied equirectangular images contain sky only in their upper half.
    /// A dome ends at the horizon so their black lower halves never cover the ground.
    static func make(_ style: SkyStyle, timeOfDay: TimeOfDay, radius: Float) -> ModelEntity? {
        guard let texture = try? TextureResource.load(named: style.imageName(for: timeOfDay), in: .main) else { return nil }
        var material = UnlitMaterial(color: .white)
        material.color = .init(tint: .white, texture: .init(texture))
        guard let mesh = dome(radius: radius) else { return nil }
        return ModelEntity(mesh: mesh, materials: [material])
    }

    private static func dome(radius: Float) -> MeshResource? {
        if let cached = meshes[radius] { return cached }
        let columns = 96, rows = 32
        var positions: [SIMD3<Float>] = []
        var uv: [SIMD2<Float>] = []
        var triangles: [UInt32] = []
        for row in 0...rows {
            let theta = Float(row) / Float(rows) * .pi / 2
            for column in 0...columns {
                // Put the panorama's bright center in front of the launch viewer; keep the seam behind.
                let phi = Float(column) / Float(columns) * 2 * .pi - .pi
                positions.append([radius * sin(theta) * sin(phi), radius * cos(theta), -radius * sin(theta) * cos(phi)])
                // RealityKit's UV origin is at the image bottom; the photograph's sky occupies its top half.
                uv.append([Float(column) / Float(columns), 1 - Float(row) / Float(rows) * 0.5])
            }
        }
        let stride = UInt32(columns + 1)
        for row in 0..<UInt32(rows) {
            for column in 0..<UInt32(columns) {
                let a = row * stride + column
                let b = a + stride
                triangles += [a, b, a + 1, a + 1, b, b + 1]
            }
        }
        var descriptor = MeshDescriptor(name: "sky-dome-\(radius)")
        descriptor.positions = MeshBuffer(positions)
        descriptor.textureCoordinates = MeshBuffer(uv)
        descriptor.primitives = .triangles(triangles)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return nil }
        meshes[radius] = mesh
        return mesh
    }
}
