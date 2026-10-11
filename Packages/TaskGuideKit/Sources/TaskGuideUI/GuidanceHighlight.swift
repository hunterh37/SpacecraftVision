import SwiftUI
import TaskGuideCore

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
    func guidanceTarget(_ id: GuidanceTargetID, coordinateSpaceName: String = "TaskGuideDemo") -> some View {
        modifier(GuidanceTargetAnchor(id: id, coordinateSpaceName: coordinateSpaceName))
    }
}

public struct GuidanceHighlightOverlay: View {
    let activeID: GuidanceTargetID?
    let bounds: [GuidanceTargetID: CGRect]
    var showsArrow: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(activeID: GuidanceTargetID?, bounds: [GuidanceTargetID: CGRect], showsArrow: Bool = false) {
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
            }
        }
    }
}
