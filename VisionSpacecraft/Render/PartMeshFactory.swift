import RealityKit
import UIKit
import RealKit
import RealLibrary
import SpacecraftCore

/// Builds craft-part and course-prop entities keyed by RealityHD id. Each lookup tries `RealityHD.entity(id)`
/// first and falls back to a procedural placeholder when the id is not yet in the catalog (specs/04).
/// Placeholders are authored with the part's base at y = 0 and its axis along +y, sized from specs/14.
@MainActor
enum PartMeshFactory {
    private static var missing: Set<String> = []
    private static var meshCache: [String: MeshResource] = [:]
    private static var textureCache: [String: TextureResource] = [:]

    enum Finish: String { case brushedSteel = "BrushedSteel", paintedMetal = "PaintedMetal", moldedPlastic = "MoldedPlastic" }

    /// Aerospace ids with a rig in RealityHD (docs/guides/articulation.md). Loaded live so flight can pose them.
    static let articulatedIds: Set<String> = [
        "command-pod", "engine-solid-small", "engine-liquid-small", "engine-prop", "decoupler", "parachute",
        "fin-trapezoid", "wing-section", "elevon", "landing-gear", "solar-panel", "lidar-sensor",
    ]

    static func entity(_ id: String, seed: UInt64 = 1, state: String? = nil) async -> Entity {
        if !missing.contains(id) {
            if articulatedIds.contains(id),
               let e = try? await RealityHD.articulated(id, seed: seed, state: state, interactive: false, grabbable: false) {
                e.name = id
                return mounted(id, e)
            }
            do {
                let e = try await RealityHD.entity(id, seed: seed)
                e.name = id
                return mounted(id, e)
            } catch {
                missing.insert(id)
            }
        }
        return placeholder(id)
    }

    /// RealityHD authors some parts in their own frame; this wraps them into the craft frame the builder
    /// uses (stack parts: base at y = 0, axis +y; radial parts: root at x = 0, extending along +x, sensors
    /// with their base on the skin). Offsets come from `realityhd stats` bounds at RealityHD b5dd02b.
    static func mounted(_ id: String, _ e: Entity) -> Entity {
        let toX = simd_quatf(angle: -.pi / 2, axis: [0, 0, 1])   // local +y -> +x
        let xToY = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])   // local +x -> +y
        let (rot, off): (simd_quatf, SIMD3<Float>)
        switch id {
        case "fuselage-section": (rot, off) = (xToY, [0, 1.00645, 0])        // barrel authored along x, 2.01 m
        case "fin-trapezoid": (rot, off) = (toX, [0, 0.464, 0])               // span +y -> outward, chord along y
        case "wing-section": (rot, off) = (simd_quatf(angle: 0, axis: [0, 1, 0]), [2.025, 0, 0])
        case "elevon": (rot, off) = (simd_quatf(angle: 0, axis: [0, 1, 0]), [0.512, 0, 0])
        case "solar-panel": (rot, off) = (simd_quatf(angle: 0, axis: [0, 1, 0]), [0.8, 0, 0])
        case "engine-solid-small": (rot, off) = (simd_quatf(angle: 0, axis: [0, 1, 0]), [0.326, 0, 0])  // lugs on -x touch the skin
        case "lidar-sensor", "radar-sensor", "camera-sensor", "imu", "battery-pack": (rot, off) = (toX, .zero)
        default: return e
        }
        let m = Entity()
        m.name = id + "-mount"
        e.orientation = rot
        e.position = off
        m.addChild(e)
        return m
    }

    /// True when the entity came from RealityHD (placeholders carry no RealityHD components).
    static func isPlaceholder(_ e: Entity) -> Bool { missing.contains(e.name) }

    // MARK: Materials

    static func metal(_ hex: UInt32, rough: Float = 0.35, metallic: Float = 0.9) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color(hex))
        m.roughness = .init(floatLiteral: rough)
        m.metallic = .init(floatLiteral: metallic)
        return m
    }

    static func paint(_ hex: UInt32, rough: Float = 0.45) -> PhysicallyBasedMaterial { metal(hex, rough: rough, metallic: 0.1) }

    /// Maps from the supplied Poliigon archives. A plain PBR material is used if a resource is unavailable.
    static func finish(_ kind: Finish) -> PhysicallyBasedMaterial {
        let fallback: PhysicallyBasedMaterial
        switch kind {
        case .brushedSteel: fallback = metal(0xB8BCC0, rough: 0.35)
        case .paintedMetal: fallback = metal(0x303238, rough: 0.65, metallic: 0.25)
        case .moldedPlastic: fallback = metal(0x45474B, rough: 0.8, metallic: 0)
        }
        guard let base = texture("\(kind.rawValue)BaseColor") else { return fallback }
        var material = fallback
        material.baseColor = .init(tint: .white, texture: .init(base))
        if let roughness = texture("\(kind.rawValue)Roughness") {
            material.roughness = .init(texture: .init(roughness))
        }
        return material
    }

    private static func texture(_ name: String) -> TextureResource? {
        if let cached = textureCache[name] { return cached }
        guard let loaded = try? TextureResource.load(named: name, in: .main) else { return nil }
        textureCache[name] = loaded
        return loaded
    }

    static func color(_ hex: UInt32, alpha: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    static func unlit(_ hex: UInt32, alpha: CGFloat = 1) -> UnlitMaterial {
        var m = UnlitMaterial(color: color(hex, alpha: alpha))
        if alpha < 1 { m.blending = .transparent(opacity: .init(floatLiteral: Float(alpha))) }
        return m
    }

    // MARK: Lathe meshes

    /// Surface of revolution around +y from a profile of (radius, y) points, with smooth normals.
    static func lathe(_ key: String, _ profile: [(Float, Float)], segments: Int = 48, closed: Bool = false) -> MeshResource {
        if let m = meshCache[key] { return m }
        var pos: [SIMD3<Float>] = [], nrm: [SIMD3<Float>] = [], uv: [SIMD2<Float>] = [], idx: [UInt32] = []
        let n = profile.count
        for (j, p) in profile.enumerated() {
            // 2D tangent along profile -> normal
            let a = profile[max(0, j - 1)], b = profile[min(n - 1, j + 1)]
            var t = SIMD2<Float>(b.0 - a.0, b.1 - a.1)
            if closed { let a2 = profile[(j - 1 + n) % n], b2 = profile[(j + 1) % n]; t = SIMD2(b2.0 - a2.0, b2.1 - a2.1) }
            let len = max(simd_length(t), 1e-6)
            let n2 = SIMD2<Float>(t.y / len, -t.x / len)
            for i in 0...segments {
                let ang = Float(i) / Float(segments) * 2 * .pi
                let c = cos(ang), s = sin(ang)
                pos.append(SIMD3(p.0 * c, p.1, p.0 * s))
                nrm.append(simd_normalize(SIMD3(n2.x * c, n2.y, n2.x * s) + SIMD3(0, 1e-6, 0)))
                uv.append(SIMD2(Float(i) / Float(segments), Float(j) / Float(max(1, n - 1))))
            }
        }
        let row = UInt32(segments + 1)
        let rows = closed ? n : n - 1
        for j in 0..<rows {
            let j1 = UInt32((j + 1) % n)
            for i in 0..<UInt32(segments) {
                let a = UInt32(j) * row + i, b = j1 * row + i
                idx += [a, b, a + 1, a + 1, b, b + 1]
            }
        }
        var d = MeshDescriptor(name: key)
        d.positions = MeshBuffer(pos)
        d.normals = MeshBuffer(nrm)
        d.textureCoordinates = MeshBuffer(uv)
        // Double-sided: add reversed triangles so open shells render from inside too.
        var both = idx
        for k in stride(from: 0, to: idx.count, by: 3) { both += [idx[k], idx[k + 2], idx[k + 1]] }
        d.primitives = .triangles(both)
        let m = (try? MeshResource.generate(from: [d])) ?? .generateSphere(radius: 0.1)
        meshCache[key] = m
        return m
    }

    static func cylinder(_ key: String, r: Float, h: Float, top: Float? = nil) -> MeshResource {
        let rt = top ?? r
        return lathe(key, [(0, 0), (r, 0), (r, 0.0001), (rt, h - 0.0001), (rt, h), (0, h)])
    }

    static func torus(innerRadius: Float, tube: Float) -> MeshResource {
        let R = innerRadius + tube
        let profile: [(Float, Float)] = (0..<24).map { i in
            let a = Float(i) / 24 * 2 * .pi
            return (R + tube * cos(a), tube * sin(a))
        }
        return lathe("torus-\(innerRadius)-\(tube)", profile, segments: 64, closed: true)
    }

    // MARK: Placeholders

    static func placeholder(_ id: String) -> Entity {
        let root = Entity()
        root.name = id
        func add(_ mesh: MeshResource, _ mat: some RealityKit.Material, at p: SIMD3<Float> = .zero, rot: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0])) {
            let e = ModelEntity(mesh: mesh, materials: [mat])
            e.position = p; e.orientation = rot
            root.addChild(e)
        }
        let white = paint(0xF2F2F0), silver = finish(.brushedSteel), dark = finish(.paintedMetal),
            steel = finish(.brushedSteel), plastic = finish(.moldedPlastic), orange = paint(0xE8622C), gold = metal(0xC9A23A, rough: 0.3)
        let r: Float = 0.625
        switch id {
        case "nose-cone":
            // Ogive 3:1 approximated by a tangent curve.
            let pts: [(Float, Float)] = (0...16).map { i in
                let t = Float(i) / 16
                return (r * sqrt(max(0, 1 - t * t)) * (1 - 0.15 * t), 1.2 * t)
            } + [(0, 1.2)]
            add(lathe("nose", [(0, 0)] + pts), white)
            add(cylinder("nose-band", r: r * 1.002, h: 0.06), orange)
        case "probe-core":
            add(cylinder("probe", r: r, h: 0.4), plastic)
            add(cylinder("probe-band", r: r * 1.01, h: 0.08), gold, at: [0, 0.16, 0])
        case "command-pod":
            add(cylinder("pod", r: r, h: 1.4, top: 0.31), white)
        case "fuel-tank-s", "fuel-tank-m", "fuel-tank-l":
            let h: Float = id == "fuel-tank-s" ? 1.0 : id == "fuel-tank-m" ? 2.0 : 4.0
            add(cylinder(id, r: r, h: h), white)
            add(cylinder(id + "-ring-a", r: r * 1.006, h: 0.05), silver)
            add(cylinder(id + "-ring-b", r: r * 1.006, h: 0.05), silver, at: [0, h - 0.05, 0])
            add(cylinder(id + "-stripe", r: r * 1.004, h: 0.12), orange, at: [0, h * 0.5, 0])
        case "engine-liquid-small":
            // Thrust structure on top, bell below; part spans 0..1.5 m.
            add(cylinder("eng-mount", r: r, h: 0.3, top: r), dark, at: [0, 1.2, 0])
            add(cylinder("eng-chamber", r: 0.18, h: 0.45), steel, at: [0, 0.8, 0])
            let bell: [(Float, Float)] = (0...12).map { i in
                let t = Float(i) / 12
                return (0.14 + 0.44 * pow(t, 1.6), 0.8 - 0.8 * t)
            }
            add(lathe("eng-bell", bell), metal(0x5A4A3E, rough: 0.4))
        case "engine-solid-small":
            add(cylinder("srb", r: 0.3, h: 1.6), white)
            add(cylinder("srb-cap", r: 0.3, h: 0.2, top: 0.05), orange, at: [0, 1.6, 0])
        case "engine-prop":
            add(cylinder("nacelle", r: 0.3, h: 0.9, top: 0.1), white)
            for k in 0..<3 {
                let blade = ModelEntity(mesh: .generateBox(size: [0.12, 0.02, 0.9]), materials: [dark])
                blade.position = [0, 0.85, 0]
                blade.orientation = simd_quatf(angle: Float(k) * 2 * .pi / 3, axis: [0, 1, 0])
                blade.position += blade.orientation.act([0, 0, 0.45])
                root.addChild(blade)
            }
        case "fin-trapezoid":
            // Root chord 0.9 along y at x = 0, span 0.6 outward along +x, swept tip.
            var d = MeshDescriptor(name: "fin")
            let p: [SIMD3<Float>] = [[0, 0, 0.01], [0.6, 0.0, 0.01], [0.6, 0.45, 0.01], [0, 0.9, 0.01],
                                     [0, 0, -0.01], [0.6, 0.0, -0.01], [0.6, 0.45, -0.01], [0, 0.9, -0.01]]
            d.positions = MeshBuffer(p)
            d.primitives = .triangles([0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6, 1, 5, 6, 1, 6, 2, 2, 6, 7, 2, 7, 3, 0, 4, 5, 0, 5, 1])
            if let m = try? MeshResource.generate(from: [d]) { add(m, orange) }
        case "decoupler":
            add(cylinder("decoupler", r: r, h: 0.2), dark)
        case "heat-shield":
            add(cylinder("shield", r: r, h: 0.15), metal(0x3A2E26, rough: 0.9, metallic: 0))
        case "parachute":
            add(cylinder("chute-pack", r: 0.2, h: 0.3), orange)
        case "battery-pack":
            add(.generateBox(size: [0.3, 0.2, 0.4], cornerRadius: 0.02), plastic, at: [0, 0.1, 0])
        case "imu":
            add(.generateBox(size: [0.1, 0.1, 0.1], cornerRadius: 0.01), gold, at: [0, 0.05, 0])
        case "lidar-sensor":
            add(cylinder("lidar", r: 0.075, h: 0.1), dark)
        case "radar-sensor":
            add(cylinder("radar", r: 0.15, h: 0.12, top: 0.05), silver)
        case "camera-sensor":
            add(.generateBox(size: [0.1, 0.1, 0.1]), dark, at: [0, 0.05, 0])
        case "fuselage-section":
            add(cylinder("fuselage", r: r, h: 2.0), white)
        case "wing-section":
            add(.generateBox(size: [3.9, 0.08, 1.4]), white, at: [1.95, 0, 0])
        case "elevon":
            add(.generateBox(size: [1.0, 0.04, 0.3]), orange, at: [0.5, 0, 0])
        case "landing-gear":
            add(cylinder("gear", r: 0.05, h: 0.9), steel)
        case "solar-panel":
            add(.generateBox(size: [1.6, 0.02, 0.6]), metal(0x1F2A44, rough: 0.2), at: [0.8, 0, 0])
        case "ring-gate":
            // Authored at inner radius 3.5 m, 8 m outer diameter, plane facing +z, base frame below.
            add(torus(innerRadius: 3.5, tube: 0.5), orange, at: [0, 4.5, 0], rot: simd_quatf(angle: .pi / 2, axis: [1, 0, 0]))
            add(.generateBox(size: [0.3, 0.6, 0.3]), dark, at: [0, 0.3, 0])
        case "pylon":
            add(cylinder("pylon", r: 0.3, h: 3, top: 0.05), orange)
        case "launch-pad":
            add(.generateBox(size: [12, 0.6, 12]), paint(0x9A9890, rough: 0.9), at: [0, 0.3, 0])
            add(.generateBox(size: [3, 0.1, 3]), dark, at: [0, 0.62, 0])
        case "launch-tower":
            for (x, z) in [(-0.8, -0.8), (0.8, -0.8), (-0.8, 0.8), (0.8, 0.8)] as [(Float, Float)] {
                add(.generateBox(size: [0.15, 14, 0.15]), paint(0xC8302C), at: [x, 7, z])
            }
            for k in 0..<7 { add(.generateBox(size: [1.8, 0.1, 1.8]), paint(0xC8302C), at: [0, 2 + Float(k) * 2, 0]) }
        case "viewing-platform":
            add(.generateBox(size: [6, 0.3, 4]), paint(0x8A8F96, rough: 0.8), at: [0, -0.15, 0])
            add(.generateBox(size: [6, 1.0, 0.05]), steel, at: [0, 0.5, -2])
        default:
            add(.generateBox(size: [0.5, 0.5, 0.5]), paint(0x6A4A9A))
        }
        return root
    }
}
