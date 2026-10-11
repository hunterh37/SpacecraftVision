import SwiftUI
import UIKit
import RealityKit
import RealKit

/// Mission backdrop: every course is flown in space. A star sphere with the Milky Way band, a lit planet
/// hanging below the deck, a sun disc, a regolith launch deck, and a slowly tumbling asteroid field around
/// the course. Visual only: the flight model, gates and corridor are unchanged.
@MainActor
enum SpaceBackdrop {
    /// Sun lighting with no sky, fog or haze. The sun entity and IBL still drive the PBR parts.
    static func environment() -> RealEnvironment? {
        var s = SunSky(elevation: 24, azimuth: 210, turbidity: 2)
        s.fogDensity = 0
        s.overcast = 0
        s.iblExposure = -1.6          // dark sky: hard sunlit sides, deep shadow sides
        s.sunLux = 11000
        s.shadowDistance = 60
        return try? RealEnvironment(s, skybox: false)
    }

    // MARK: Sky

    static func sky(radius: Float = 5800) -> Entity {
        let root = Entity()
        root.name = "space-sky"
        var m = UnlitMaterial(color: .black)
        if let tex = starTexture() { m.color = .init(tint: .white, texture: .init(tex)) }
        let sphere = ModelEntity(mesh: .generateSphere(radius: radius), materials: [m])
        sphere.scale = [-1, 1, 1]       // render the inside
        root.addChild(sphere)

        // Sun disc and glow on the light direction (elevation 24, azimuth 210).
        let el: Float = 24 * .pi / 180, az: Float = 210 * .pi / 180
        let dir = SIMD3<Float>(cos(el) * sin(az), sin(el), -cos(el) * cos(az))
        let sun = ModelEntity(mesh: .generateSphere(radius: radius * 0.012), materials: [UnlitMaterial(color: UIColor(red: 1, green: 0.97, blue: 0.9, alpha: 1))])
        sun.position = dir * radius * 0.95
        root.addChild(sun)
        for (k, a) in [(2.6, 0.25), (6.0, 0.08)] as [(Float, CGFloat)] {
            var g = UnlitMaterial(color: UIColor(red: 1, green: 0.85, blue: 0.6, alpha: a))
            g.blending = .transparent(opacity: .init(floatLiteral: Float(a)))
            let glow = ModelEntity(mesh: .generateSphere(radius: radius * 0.012 * k), materials: [g])
            glow.position = sun.position
            root.addChild(glow)
        }
        return root
    }

    /// Equirectangular star field: dense faint stars, a few bright coloured ones, a dusty galactic band.
    private static func starTexture() -> TextureResource? {
        let size = CGSize(width: 4096, height: 2048)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor(red: 0.004, green: 0.006, blue: 0.014, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))
            var rng = SeededGen(seed: 77)
            // Galactic band: a tilted sine across the panorama, built from soft blobs.
            for _ in 0..<2600 {
                let x = CGFloat(rng.next()) * size.width
                let centre = size.height * 0.42 + sin(x / size.width * 2 * .pi) * size.height * 0.16
                let spread = CGFloat(rng.gauss()) * size.height * 0.05
                let r = CGFloat(20 + rng.next() * 70)
                let warm = rng.next()
                c.setFillColor(UIColor(red: 0.55 + 0.3 * warm, green: 0.5 + 0.15 * warm, blue: 0.75 - 0.25 * warm, alpha: 0.018).cgColor)
                c.fillEllipse(in: CGRect(x: x - r, y: centre + spread - r * 0.6, width: r * 2, height: r * 1.2))
            }
            // Dust lane.
            for _ in 0..<900 {
                let x = CGFloat(rng.next()) * size.width
                let centre = size.height * 0.42 + sin(x / size.width * 2 * .pi) * size.height * 0.16
                let r = CGFloat(10 + rng.next() * 30)
                c.setFillColor(UIColor(white: 0, alpha: 0.05).cgColor)
                c.fillEllipse(in: CGRect(x: x - r, y: centre + CGFloat(rng.gauss()) * 12 - r * 0.4, width: r * 2, height: r * 0.8))
            }
            // Faint stars, denser in the band.
            for i in 0..<26000 {
                let x = CGFloat(rng.next()) * size.width
                var y = CGFloat(rng.next()) * size.height
                if i % 3 == 0 { y = size.height * 0.42 + sin(x / size.width * 2 * .pi) * size.height * 0.16 + CGFloat(rng.gauss()) * size.height * 0.06 }
                let a = 0.15 + rng.next() * 0.55, r = CGFloat(0.6 + rng.next() * 0.9)
                c.setFillColor(UIColor(white: 1, alpha: a).cgColor)
                c.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
            // Bright stars with a halo.
            let tints: [UIColor] = [.white, UIColor(red: 0.7, green: 0.82, blue: 1, alpha: 1), UIColor(red: 1, green: 0.86, blue: 0.68, alpha: 1), UIColor(red: 1, green: 0.7, blue: 0.55, alpha: 1)]
            for _ in 0..<420 {
                let x = CGFloat(rng.next()) * size.width, y = CGFloat(rng.next()) * size.height
                let t = tints[Int(rng.next() * 4) % 4], r = CGFloat(1.6 + rng.next() * 2.2)
                c.setFillColor(t.withAlphaComponent(0.12).cgColor)
                c.fillEllipse(in: CGRect(x: x - r * 2, y: y - r * 2, width: r * 5, height: r * 5))
                c.setFillColor(t.cgColor)
                c.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
        }
        guard let cg = img.cgImage else { return nil }
        return try? TextureResource(image: cg, options: .init(semantic: .color))
    }

    // MARK: Planet

    /// Large ocean planet far below and ahead of the deck, with cloud bands and a blue limb.
    static func planet() -> Entity {
        let root = Entity()
        root.name = "space-planet"
        let r: Float = 1600
        var m = PhysicallyBasedMaterial()
        if let tex = planetTexture() { m.baseColor = .init(tint: .white, texture: .init(tex)) }
        m.roughness = 0.8; m.metallic = .init(floatLiteral: 0)
        let body = ModelEntity(mesh: .generateSphere(radius: r), materials: [m])
        root.addChild(body)
        var limb = UnlitMaterial(color: UIColor(red: 0.35, green: 0.62, blue: 1, alpha: 0.18))
        limb.blending = .transparent(opacity: 0.18)
        let atmo = ModelEntity(mesh: .generateSphere(radius: r * 1.025), materials: [limb])
        root.addChild(atmo)
        root.position = [-900, -2300, -3400]
        root.orientation = simd_quatf(angle: 0.35, axis: simd_normalize([0.3, 0, 1]))
        return root
    }

    private static func planetTexture() -> TextureResource? {
        let size = CGSize(width: 2048, height: 1024)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor(red: 0.04, green: 0.13, blue: 0.32, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))
            var rng = SeededGen(seed: 5)
            // Continents: clustered blobs in green-brown.
            for _ in 0..<9 {
                let cx = CGFloat(rng.next()) * size.width, cy = size.height * (0.2 + CGFloat(rng.next()) * 0.6)
                for _ in 0..<160 {
                    let x = cx + CGFloat(rng.gauss()) * 120, y = cy + CGFloat(rng.gauss()) * 70, rr = CGFloat(8 + rng.next() * 30)
                    let g = rng.next()
                    c.setFillColor(UIColor(red: 0.22 + 0.25 * g, green: 0.3 + 0.12 * g, blue: 0.14, alpha: 0.85).cgColor)
                    c.fillEllipse(in: CGRect(x: x, y: y, width: rr * 1.6, height: rr))
                }
            }
            // Ice caps.
            c.setFillColor(UIColor(white: 0.93, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.06))
            c.fill(CGRect(x: 0, y: size.height * 0.94, width: size.width, height: size.height * 0.06))
            // Cloud streaks.
            for _ in 0..<1400 {
                let x = CGFloat(rng.next()) * size.width, y = CGFloat(rng.next()) * size.height
                let w = CGFloat(30 + rng.next() * 160), h = CGFloat(4 + rng.next() * 14)
                c.setFillColor(UIColor(white: 1, alpha: 0.12 + rng.next() * 0.25).cgColor)
                c.fillEllipse(in: CGRect(x: x, y: y, width: w, height: h))
            }
        }
        guard let cg = img.cgImage else { return nil }
        return try? TextureResource(image: cg, options: .init(semantic: .color))
    }

    // MARK: Deck

    /// Grey regolith launch deck with craters, in place of the desert floor.
    static func deck(size: Float = 6000) -> Entity {
        var m = PhysicallyBasedMaterial()
        if let tex = regolithTexture() {
            m.baseColor = .init(tint: .white, texture: .init(tex))
            m.textureCoordinateTransform = .init(scale: [size / 40, size / 40])
        } else {
            m.baseColor = .init(tint: UIColor(white: 0.36, alpha: 1))
        }
        m.roughness = 0.97; m.metallic = .init(floatLiteral: 0)
        let e = ModelEntity(mesh: .generatePlane(width: size, depth: size), materials: [m])
        e.name = "space-deck"
        e.position = [0, -0.02, 0]
        return e
    }

    private static func regolithTexture() -> TextureResource? {
        let size = CGSize(width: 1024, height: 1024)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor(white: 0.38, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))
            var rng = SeededGen(seed: 19)
            for _ in 0..<9000 {
                let x = CGFloat(rng.next()) * size.width, y = CGFloat(rng.next()) * size.height, r = CGFloat(1 + rng.next() * 6)
                c.setFillColor(UIColor(white: 0.25 + rng.next() * 0.25, alpha: 0.5).cgColor)
                c.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
            for _ in 0..<40 {   // craters: dark floor, bright rim on the sun side
                let x = CGFloat(rng.next()) * size.width, y = CGFloat(rng.next()) * size.height, r = CGFloat(10 + rng.next() * 70)
                c.setFillColor(UIColor(white: 0.24, alpha: 0.55).cgColor)
                c.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                c.setStrokeColor(UIColor(white: 0.58, alpha: 0.6).cgColor)
                c.setLineWidth(max(2, r * 0.12))
                c.addArc(center: CGPoint(x: x, y: y), radius: r, startAngle: .pi * 0.9, endAngle: .pi * 1.9, clockwise: false)
                c.strokePath()
            }
        }
        guard let cg = img.cgImage else { return nil }
        return try? TextureResource(image: cg, options: .init(semantic: .color))
    }

    // MARK: Asteroids

    /// A field of procedural asteroids placed around the course volume, kept clear of the launch pad, the
    /// viewing platform and a tube around every gate so they never sit on the flown line.
    static func asteroids(extent: SIMD3<Float>, keepClear: [(SIMD3<Float>, Float)], count: Int = 26, seed: UInt64 = 9) -> Entity {
        let root = Entity()
        root.name = "space-asteroids"
        var rng = SeededGen(seed: seed)
        let meshes = (0..<5).compactMap { rockMesh(seed: UInt64($0) + seed * 31) }
        guard !meshes.isEmpty else { return root }
        let mats: [PhysicallyBasedMaterial] = [0.30, 0.40, 0.24].map { w in
            var m = PhysicallyBasedMaterial()
            m.baseColor = .init(tint: UIColor(red: CGFloat(w) * 1.08, green: CGFloat(w), blue: CGFloat(w) * 0.92, alpha: 1))
            m.roughness = 0.93; m.metallic = 0.04
            return m
        }
        let span = SIMD3<Float>(max(extent.x, 600), max(extent.z, 400), max(extent.y, 900))  // RealityKit axes
        var placed = 0, tries = 0
        while placed < count && tries < count * 40 {
            tries += 1
            let p = SIMD3<Float>((Float(rng.next()) - 0.5) * span.x * 1.6,
                                 40 + Float(rng.next()) * span.y * 1.2,
                                 -Float(rng.next()) * span.z * 1.3 + 120)
            let size = Float(4 + pow(rng.next(), 2.2) * 38)
            if keepClear.contains(where: { simd_distance($0.0, p) < $0.1 + size * 1.4 }) { continue }
            let e = ModelEntity(mesh: meshes[placed % meshes.count], materials: [mats[placed % mats.count]])
            e.position = p
            e.scale = SIMD3(size, size * Float(0.7 + rng.next() * 0.5), size * Float(0.8 + rng.next() * 0.4))
            e.orientation = simd_quatf(angle: Float(rng.next()) * 6.28, axis: simd_normalize(SIMD3(Float(rng.next()) - 0.5, Float(rng.next()) - 0.5, Float(rng.next()) - 0.5) + 0.001))
            e.components.set(Tumble(axis: simd_normalize(SIMD3(Float(rng.next()), 1, Float(rng.next()))), rate: Float(0.02 + rng.next() * 0.08)))
            root.addChild(e)
            placed += 1
        }
        return root
    }

    /// Spin each asteroid about its own axis. Called from the scene update.
    static func tumble(_ root: Entity, dt: Float) {
        for e in root.children {
            guard let t = e.components[Tumble.self] else { continue }
            e.orientation = simd_quatf(angle: t.rate * dt, axis: t.axis) * e.orientation
        }
    }

    struct Tumble: Component { var axis: SIMD3<Float>; var rate: Float }

    /// Unit-radius icosphere displaced by layered value noise plus a few crater dents.
    private static func rockMesh(seed: UInt64) -> MeshResource? {
        var verts: [SIMD3<Float>] = []
        var tris: [UInt32] = []
        let t: Float = (1 + Float(5).squareRoot()) / 2
        verts = [[-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0], [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t],
                 [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]].map { simd_normalize(SIMD3<Float>($0)) }
        tris = [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
                3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
        for _ in 0..<4 {
            var cache: [UInt64: UInt32] = [:]
            func mid(_ a: UInt32, _ b: UInt32) -> UInt32 {
                let key = UInt64(min(a, b)) << 32 | UInt64(max(a, b))
                if let i = cache[key] { return i }
                verts.append(simd_normalize((verts[Int(a)] + verts[Int(b)]) / 2))
                let i = UInt32(verts.count - 1); cache[key] = i; return i
            }
            var next: [UInt32] = []
            for i in stride(from: 0, to: tris.count, by: 3) {
                let a = tris[i], b = tris[i + 1], c = tris[i + 2]
                let ab = mid(a, b), bc = mid(b, c), ca = mid(c, a)
                next += [a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca]
            }
            tris = next
        }
        var rng = SeededGen(seed: seed)
        let offs = (0..<4).map { _ in SIMD3<Float>(Float(rng.next()) * 50, Float(rng.next()) * 50, Float(rng.next()) * 50) }
        let craters = (0..<6).map { _ in (simd_normalize(SIMD3<Float>(Float(rng.gauss()), Float(rng.gauss()), Float(rng.gauss()))), Float(0.25 + rng.next() * 0.35)) }
        verts = verts.map { v in
            var h: Float = 0, amp: Float = 0.28, freq: Float = 1.3
            for o in offs { h += amp * valueNoise(v * freq + o); amp *= 0.5; freq *= 2.1 }
            for (cd, cr) in craters {
                let d = simd_distance(v, cd)
                if d < cr { let x = d / cr; h -= 0.12 * (1 - x * x) } else if d < cr * 1.25 { h += 0.03 }
            }
            return v * (1 + h)
        }
        var normals = [SIMD3<Float>](repeating: .zero, count: verts.count)
        for i in stride(from: 0, to: tris.count, by: 3) {
            let a = Int(tris[i]), b = Int(tris[i + 1]), c = Int(tris[i + 2])
            let n = simd_cross(verts[b] - verts[a], verts[c] - verts[a])
            normals[a] += n; normals[b] += n; normals[c] += n
        }
        var d = MeshDescriptor(name: "asteroid-\(seed)")
        d.positions = MeshBuffer(verts)
        d.normals = MeshBuffer(normals.map { simd_normalize($0) })
        d.primitives = .triangles(tris)
        return try? MeshResource.generate(from: [d])
    }

    private static func valueNoise(_ p: SIMD3<Float>) -> Float {
        let i = floor(p), f = p - i
        let u = f * f * (3 - 2 * f)
        func h(_ x: Float, _ y: Float, _ z: Float) -> Float {
            var n = UInt32(bitPattern: Int32(truncatingIfNeeded: Int(x) &* 73856093 ^ Int(y) &* 19349663 ^ Int(z) &* 83492791))
            n = (n << 13) ^ n
            n = n &* (n &* n &* 15731 &+ 789221) &+ 1376312589
            return Float(n & 0x7fffffff) / Float(0x7fffffff) * 2 - 1
        }
        let a = h(i.x, i.y, i.z), b = h(i.x + 1, i.y, i.z), c = h(i.x, i.y + 1, i.z), d = h(i.x + 1, i.y + 1, i.z)
        let e = h(i.x, i.y, i.z + 1), f2 = h(i.x + 1, i.y, i.z + 1), g = h(i.x, i.y + 1, i.z + 1), k = h(i.x + 1, i.y + 1, i.z + 1)
        let x1 = a + (b - a) * u.x, x2 = c + (d - c) * u.x, x3 = e + (f2 - e) * u.x, x4 = g + (k - g) * u.x
        let y1 = x1 + (x2 - x1) * u.y, y2 = x3 + (x4 - x3) * u.y
        return y1 + (y2 - y1) * u.z
    }
}

/// Deterministic generator for the backdrop so every launch shows the same sky and field.
struct SeededGen {
    private var s: UInt64
    init(seed: UInt64) { s = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> Double {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
    mutating func gauss() -> Double {
        let u = max(next(), 1e-9), v = next()
        return (-2 * log(u)).squareRoot() * cos(2 * .pi * v)
    }
}
