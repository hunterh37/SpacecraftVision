import SwiftUI

/// Brand palette: deep-space navy, ignition orange, telemetry cyan.
enum Brand {
    static let space = Color(red: 0.035, green: 0.051, blue: 0.098)      // #090D19
    static let hull = Color(red: 0.086, green: 0.110, blue: 0.180)       // #161C2E
    static let ignition = Color(red: 1.0, green: 0.42, blue: 0.13)       // #FF6B21
    static let telemetry = Color(red: 0.31, green: 0.86, blue: 0.95)     // #4FDBF2
    static let trajectory = Color(red: 0.72, green: 0.56, blue: 1.0)     // #B78FFF
    static let ink = Color.white
    static let dim = Color.white.opacity(0.55)

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded).width(.expanded) }
    static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }
}

struct BrandBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Brand.hull, Brand.space], startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                var rng = SeededRNG(seed: 7)
                for _ in 0..<90 {
                    let x = CGFloat(rng.next()) * size.width, y = CGFloat(rng.next()) * size.height
                    let r = 0.6 + CGFloat(rng.next()) * 1.4
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(.white.opacity(0.15 + Double(rng.next()) * 0.4)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

struct BrandButtonStyle: ButtonStyle {
    var tint: Color = Brand.ignition
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Brand.label(15))
            .foregroundStyle(Brand.space)
            .padding(.horizontal, 22).padding(.vertical, 12)
            .background(tint, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .hoverEffect(.lift)
    }
}
