// The app's brand tokens. Lives here so the app screens and LabUI share one source of truth.
import SwiftUI

/// Brand palette: deep-space navy, ignition orange, telemetry cyan.
public enum Brand {
    public static let space = Color(red: 0.035, green: 0.051, blue: 0.098)      // #090D19
    public static let hull = Color(red: 0.086, green: 0.110, blue: 0.180)       // #161C2E
    public static let ignition = Color(red: 1.0, green: 0.42, blue: 0.13)       // #FF6B21
    public static let telemetry = Color(red: 0.31, green: 0.86, blue: 0.95)     // #4FDBF2
    public static let trajectory = Color(red: 0.72, green: 0.56, blue: 1.0)     // #B78FFF
    public static let ink = Color.white
    public static let dim = Color.white.opacity(0.55)

    public static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded).width(.expanded) }
    public static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }
}

public struct BrandBackground: View {
    public init() {}
    public var body: some View {
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

public struct SeededRNG {
    public var state: UInt64
    public init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 }
    public mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}


/// The primary button: tint-to-light capsule with a glow, mono label in tracked capitals. Every existing `BrandButtonStyle` use picks this up.
public struct BrandButtonStyle: ButtonStyle {
    public var tint: Color
    public init(tint: Color = Brand.ignition) { self.tint = tint }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Brand.label(14)).tracking(1.2)
            .foregroundStyle(Brand.space)
            .padding(.horizontal, 22).padding(.vertical, 12)
            .background(Capsule().fill(LinearGradient(colors: [tint, tint.opacity(0.78)], startPoint: .top, endPoint: .bottom)))
            .overlay { Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1) }
            .shadow(color: tint.opacity(0.45), radius: configuration.isPressed ? 4 : 12)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .lift()
    }
}

/// Secondary action: tinted outline capsule, readable on any surface.
public struct LabSecondaryButtonStyle: ButtonStyle {
    public var tint: Color
    public init(tint: Color = Brand.telemetry) { self.tint = tint }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Brand.label(13)).tracking(1)
            .foregroundStyle(Brand.ink)
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(Capsule().fill(tint.opacity(configuration.isPressed ? 0.28 : 0.14)))
            .overlay { Capsule().strokeBorder(tint.opacity(0.55), lineWidth: 1) }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .lift()
    }
}
