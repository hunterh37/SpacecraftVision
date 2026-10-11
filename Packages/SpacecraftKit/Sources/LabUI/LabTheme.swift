import SwiftUI
import Curriculum

/// Design tokens for the coding and trace surfaces. Every container carries its own atmosphere
/// (aurora streaks, light shaft, stars, grain, frame lines), because the app sits over passthrough
/// and has no page background to borrow depth from.
public enum Lab {
    // Surfaces and accents come from `Brand`, so the app and the coding surfaces share one palette.
    public static let navy = Brand.space
    public static let hull = Brand.hull
    public static let ink = Brand.ink
    public static let muted = Color(red: 0.76, green: 0.80, blue: 0.96)
    public static let faint = Color(red: 0.42, green: 0.45, blue: 0.68)
    public static let edge = Color(red: 0.67, green: 0.71, blue: 1.0)
    public static let teal = Brand.telemetry          // telemetry cyan
    public static let violet = Brand.trajectory
    public static let amber = Brand.ignition
    public static let ember = Brand.ignition
    public static let gold = Brand.ignition
    public static let pink = Color(red: 1.0, green: 0.478, blue: 0.784)
    public static let danger = Color(red: 1.0, green: 0.416, blue: 0.353)

    // Fonts. The licensed brand faces are used when the app bundle carries them; otherwise Brand's own
    // system faces take over, so the look stays coherent either way.
    private static func face(_ name: String, _ size: CGFloat, _ style: Font.TextStyle, fallback: Font) -> Font {
        PlatformFont(name: name, size: size) != nil ? .custom(name, size: size, relativeTo: style) : fallback
    }
    public static func display(_ size: CGFloat) -> Font { face("PoleaExtraBoldDEMO", size, .title, fallback: Brand.display(size)) }
    public static func label(_ size: CGFloat) -> Font { face("Nebula", size, .caption, fallback: Brand.label(size)) }
    public static func soft(_ size: CGFloat) -> Font { face("KreganDEMO-Regular", size, .body, fallback: .system(size: size, weight: .semibold, design: .rounded)) }
    public static func mono(_ size: CGFloat) -> Font { .system(size: size, design: .monospaced) }

    // Blocks (Scratch-like hues)
    static func hue(_ c: BlockCategory) -> Double {
        switch c {
        case .motion: 215; case .sensing: 188; case .operators: 135; case .control: 36; case .variables: 12; case .event: 52
        }
    }
    public static func blockFill(_ c: BlockCategory) -> Color { Color(hue: hue(c) / 360, saturation: 0.70, brightness: 0.93) }
    public static func blockEdge(_ c: BlockCategory) -> Color { Color(hue: hue(c) / 360, saturation: 0.78, brightness: 0.58) }
    public static func blockGlow(_ c: BlockCategory) -> Color { Color(hue: hue(c) / 360, saturation: 0.55, brightness: 1.0) }
    static let variablePill = Color(hue: 12 / 360, saturation: 0.75, brightness: 0.95)

    // Syntax colours (VS Code dark-ish, tuned for the navy surface)
    enum Syntax {
        static let keyword = Color(red: 0.39, green: 0.89, blue: 0.78)
        static let function = Color(red: 0.49, green: 0.77, blue: 1.0)
        static let number = Color(red: 1.0, green: 0.65, blue: 0.42)
        static let string = Color(red: 0.48, green: 0.91, blue: 0.54)
        static let variable = Color(red: 1.0, green: 0.55, blue: 0.63)
        static let builtin = Color(red: 0.77, green: 0.55, blue: 1.0)
        static let punct = Color(red: 1.0, green: 0.85, blue: 0.42)
        static let op = Color(red: 0.56, green: 0.63, blue: 0.84)
        static let comment = Color(red: 0.42, green: 0.48, blue: 0.61)
        static let plain = Color(red: 0.80, green: 0.84, blue: 0.96)
    }
}

// MARK: - Aurora texture

struct SplitMix: Sendable {
    var state: UInt64
    init(_ seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
}

public enum AuroraVariant: Sendable {
    /// Cyan to violet: the default for code and trace surfaces.
    case dusk
    /// Cyan, green, blue: calm, used for block editing.
    case tide
    /// Orange, pink, violet: warm, for missions and flight.
    case ember
    var palette: [Color] {
        switch self {
        case .dusk: [Brand.telemetry, Color(red: 0.36, green: 0.55, blue: 1.0), Brand.trajectory, Lab.pink]
        case .tide: [Brand.telemetry, Color(red: 0.47, green: 1.0, blue: 0.67), Color(red: 0.36, green: 0.67, blue: 1.0), Brand.trajectory]
        case .ember: [Brand.ignition, Lab.pink, Brand.trajectory, Brand.telemetry]
        }
    }
    var seed: UInt64 { switch self { case .dusk: 5; case .tide: 11; case .ember: 17 } }
}

/// Falling aurora bars, a light shaft, nebula glow, stars and sparkles, drawn procedurally and seeded so
/// it is identical every launch. `strength` keeps text readable on top of it.
public struct AuroraLayer: View {
    public var variant: AuroraVariant
    public var strength: Double
    public init(variant: AuroraVariant = .dusk, strength: Double = 0.5) { self.variant = variant; self.strength = strength }

    public var body: some View {
        Canvas { ctx, size in
            guard size.width > 8, size.height > 8 else { return }
            var rng = SplitMix(variant.seed)
            let pal = variant.palette, w = size.width, h = size.height
            ctx.opacity = strength
            // nebula glow
            for (x, y, r, c) in [(0.2, 0.62, 0.55, pal[2]), (0.82, 0.5, 0.5, pal[1]), (0.5, 0.9, 0.6, pal[3])] {
                let center = CGPoint(x: x * w, y: y * h)
                let rect = CGRect(x: center.x - r * w, y: center.y - r * w, width: 2 * r * w, height: 2 * r * w)
                ctx.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [c.opacity(0.22), c.opacity(0)]), center: center, startRadius: 0, endRadius: r * w))
            }
            // light shaft with fine rules
            let sw = w * 0.16, sx = w * (0.4 + rng.next() * 0.2)
            ctx.fill(Path(CGRect(x: sx, y: 0, width: sw, height: h)),
                     with: .linearGradient(Gradient(stops: [.init(color: Color(red: 0.35, green: 0.43, blue: 1).opacity(0), location: 0), .init(color: Color(red: 0.35, green: 0.43, blue: 1).opacity(0.2), location: 0.35),
                                                            .init(color: Color(red: 0.6, green: 0.47, blue: 1).opacity(0.14), location: 0.8), .init(color: Brand.ignition.opacity(0.22), location: 1)]),
                                           startPoint: CGPoint(x: sx, y: 0), endPoint: CGPoint(x: sx, y: h)))
            var rule = Path(); var x = sx
            while x < sx + sw { rule.addRect(CGRect(x: x, y: 0, width: 1, height: h)); x += 9 }
            ctx.fill(rule, with: .color(Color(red: 0.75, green: 0.78, blue: 1).opacity(0.16)))
            // aurora bars
            struct Band { var base: Double, amp: Double, len: Double, ph: Double, a: Double }
            let bands: [Band] = [Band(base: 0.62, amp: 0.10, len: 0.34, ph: 1 + rng.next() * 3, a: 1), Band(base: 0.40, amp: 0.09, len: 0.26, ph: 4 + rng.next() * 3, a: 0.7)]
            for (bi, b) in bands.enumerated() {
                let c0: Color = pal[(bi * 2) % 4], c1: Color = pal[(bi * 2 + 1) % 4], c2: Color = pal[(bi * 2 + 2) % 4]
                var bx: Double = 4
                while bx < Double(w) {
                    let wave1: Double = b.amp * sin(bx * 0.0085 + b.ph)
                    let wave2: Double = 0.05 * sin(bx * 0.024 + b.ph * 2)
                    let top: Double = Double(h) * (b.base + wave1 + wave2)
                    let lenWave: Double = 0.5 + 0.5 * sin(bx * 0.013 + b.ph * 1.7)
                    let len: Double = Double(h) * b.len * (0.35 + 0.65 * lenWave) + 20
                    let stops: [Gradient.Stop] = [
                        .init(color: c0.opacity(0), location: 0), .init(color: c0.opacity(0.85 * b.a), location: 0.18),
                        .init(color: c1.opacity(0.45 * b.a), location: 0.6), .init(color: c2.opacity(0), location: 1)]
                    let rect = CGRect(x: bx, y: top, width: 3.4, height: len)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1.7),
                             with: .linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: bx, y: top), endPoint: CGPoint(x: bx, y: top + len)))
                    bx += 8
                }
            }
            // stars and four-point sparkles
            for _ in 0..<Int(min(160, w * h / 5000)) {
                let big = rng.next() < 0.06 ? 2.0 : 1.0
                ctx.fill(Path(CGRect(x: rng.next() * w, y: rng.next() * h, width: big, height: big)), with: .color(Color(red: 0.88, green: 0.9, blue: 1).opacity(0.15 + rng.next() * 0.7)))
            }
            for i in 0..<7 {
                let cx = rng.next() * w, cy = rng.next() * h * 0.8, s = 4 + rng.next() * 5
                var p = Path(); p.move(to: CGPoint(x: cx - s, y: cy)); p.addLine(to: CGPoint(x: cx + s, y: cy)); p.move(to: CGPoint(x: cx, y: cy - s)); p.addLine(to: CGPoint(x: cx, y: cy + s))
                ctx.stroke(p, with: .color(pal[i % 4].opacity(0.8)), lineWidth: 1.3)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Fine film grain, seeded, drawn as sparse dots.
struct GrainLayer: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SplitMix(99)
            let n = Int(min(2600, size.width * size.height / 90))
            for _ in 0..<n { ctx.fill(Path(CGRect(x: rng.next() * size.width, y: rng.next() * size.height, width: 1, height: 1)), with: .color(.white.opacity(0.03 + rng.next() * 0.07))) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

public extension View {
    /// A Brand card with extra depth: hull-to-space base, a warm ignition glow at the floor, a tinted glow at the top,
    /// aurora streaks, grain, and a tinted hairline plus inner frame. Self-contained, so it reads over passthrough.
    func labPanel(corner: CGFloat = 32, tint: Color = Brand.telemetry, variant: AuroraVariant = .dusk, aurora: Double = 0.4) -> some View {
        background {
            ZStack {
                LinearGradient(colors: [Brand.hull, Color(red: 0.06, green: 0.08, blue: 0.14), Brand.space], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Brand.ignition.opacity(0.26), .clear], center: .bottom, startRadius: 0, endRadius: 340)
                RadialGradient(colors: [tint.opacity(0.20), .clear], center: .top, startRadius: 0, endRadius: 320)
                AuroraLayer(variant: variant, strength: aurora)
                GrainLayer()
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        }
        .overlay { RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(tint.opacity(0.38), lineWidth: 1) }
        .overlay { RoundedRectangle(cornerRadius: max(corner - 8, 4), style: .continuous).inset(by: 9).stroke(tint.opacity(0.12), lineWidth: 1).allowsHitTesting(false) }
        .shadow(color: tint.opacity(0.16), radius: 26)
    }
}
