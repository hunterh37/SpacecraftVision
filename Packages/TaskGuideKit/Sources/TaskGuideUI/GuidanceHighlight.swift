import SwiftUI
import TaskGuideCore

/// Preference key that publishes target bounds in a shared coordinate space.
public struct GuidanceTargetBoundsKey: PreferenceKey {
    public static let defaultValue: [GuidanceTargetID: CGRect] = [:]

    public static func reduce(value: inout [GuidanceTargetID: CGRect], nextValue: () -> [GuidanceTargetID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct GuidanceTargetAnchor: ViewModifier {
    let id: GuidanceTargetID
    let coordinateSpaceName: String

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: GuidanceTargetBoundsKey.self,
                    value: [id: geo.frame(in: .named(coordinateSpaceName))]
                )
            }
        )
    }
}

public extension View {
    /// Marks a UI element as a guidance target within a named coordinate space.
    func guidanceTarget(_ id: GuidanceTargetID, coordinateSpaceName: String = "TaskGuideDemo") -> some View {
        modifier(GuidanceTargetAnchor(id: id, coordinateSpaceName: coordinateSpaceName))
    }
}

/// Subtle ring outline drawn around the active guidance target bounds.
public struct GuidanceHighlightOverlay: View {
    let activeID: GuidanceTargetID?
    let bounds: [GuidanceTargetID: CGRect]
    var showsArrow: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(activeID: GuidanceTargetID?, bounds: [GuidanceTargetID: CGRect], showsArrow: Bool = true) {
        self.activeID = activeID
        self.bounds = bounds
        self.showsArrow = showsArrow
    }

    public var body: some View {
        ZStack {
            if let activeID, let rect = bounds[activeID] {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.95), lineWidth: 2)
                    .frame(width: rect.width + 8, height: rect.height + 8)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                if showsArrow && !reduceMotion {
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
