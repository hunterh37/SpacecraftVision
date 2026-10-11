import SwiftUI
import TaskGuideCore

/// Preference key that publishes target bounds in a shared coordinate space.
struct GuidanceTargetBoundsKey: PreferenceKey {
    static let defaultValue: [GuidanceTargetID: CGRect] = [:]

    static func reduce(value: inout [GuidanceTargetID: CGRect], nextValue: () -> [GuidanceTargetID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct GuidanceTargetAnchor: ViewModifier {
    let id: GuidanceTargetID
    let coordinateSpace: CoordinateSpace

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: GuidanceTargetBoundsKey.self,
                    value: [id: geo.frame(in: coordinateSpace)]
                )
            }
        )
    }
}

public extension View {
    /// Marks a representative UI element as a guidance target for the 2D preview.
    func guidanceTarget(_ id: GuidanceTargetID, coordinateSpace: CoordinateSpace = .named("TaskGuideDemo")) -> some View {
        modifier(GuidanceTargetAnchor(id: id, coordinateSpace: coordinateSpace))
    }
}

/// Subtle ring outline drawn around the active guidance target bounds.
struct GuidanceHighlightOverlay: View {
    let activeID: GuidanceTargetID?
    let bounds: [GuidanceTargetID: CGRect]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let activeID, let rect = bounds[activeID] {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.95), lineWidth: 2)
                    .frame(width: rect.width + 8, height: rect.height + 8)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                if !reduceMotion {
                    GuidanceArrow(from: arrowOrigin(for: rect), to: rect)
                        .stroke(Color.accentColor.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    /// Prefer pointing from near the task board (leading side) toward the target.
    private func arrowOrigin(for rect: CGRect) -> CGPoint {
        CGPoint(x: max(24, rect.minX - 40), y: rect.midY)
    }
}

private struct GuidanceArrow: Shape {
    let from: CGPoint
    let to: CGRect

    func path(in _: CGRect) -> Path {
        let tip = CGPoint(x: to.minX - 6, y: to.midY)
        var path = Path()
        path.move(to: from)
        path.addLine(to: tip)
        // Arrow head
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x - 8, y: tip.y - 5))
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x - 8, y: tip.y + 5))
        return path
    }
}
