import RealityKit
import UIKit

/// Chase-view comfort vignette (specs/03): a head-locked dark ring that fades in above 30 deg/s of view rotation
/// and is full at 90 deg/s. Off when the comfort setting is off.
@MainActor
final class ComfortVignette {
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "comfortVignette") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "comfortVignette") }
    }

    let root = AnchorEntity(.head)
    private let ring: ModelEntity
    private var opacity: Float = 0

    init() {
        var m = UnlitMaterial()
        if let tex = Self.ringTexture() {
            m.color = .init(tint: .white, texture: .init(tex))
        } else {
            m.color = .init(tint: .black)
        }
        m.blending = .transparent(opacity: .init(floatLiteral: 0))
        ring = ModelEntity(mesh: .generatePlane(width: 1.6, height: 1.2), materials: [m])
        ring.position = [0, 0, -0.45]
        ring.isEnabled = false
        root.addChild(ring)
    }

    func update(rateDegPerSec rate: Float, dt: Float) {
        let target: Float = Self.enabled ? min(1, max(0, (rate - 30) / 60)) : 0
        // Fade in over 0.2 s, out over 0.6 s.
        let k = min(1, dt / (target > opacity ? 0.2 : 0.6))
        opacity += (target - opacity) * k
        ring.isEnabled = opacity > 0.01
        if var m = ring.model?.materials.first as? UnlitMaterial {
            m.blending = .transparent(opacity: .init(floatLiteral: opacity * 0.9))
            ring.model?.materials = [m]
        }
    }

    /// Black ring with a clear centre (radial alpha gradient).
    static func ringTexture() -> TextureResource? {
        let size = 256
        let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let ctx else { return nil }
        let colors = [UIColor(white: 0, alpha: 0).cgColor, UIColor(white: 0, alpha: 0).cgColor, UIColor(white: 0, alpha: 1).cgColor] as CFArray
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.45, 0.95]) else { return nil }
        let c = CGPoint(x: size / 2, y: size / 2)
        ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: CGFloat(size) * 0.72,
                               options: [.drawsAfterEndLocation])
        guard let img = ctx.makeImage() else { return nil }
        return try? TextureResource(image: img, options: .init(semantic: .color))
    }
}
