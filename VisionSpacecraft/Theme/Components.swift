import SwiftUI
import LabUI

/// Card surface: hull glass with a telemetry hairline.
struct BrandCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(20)
            .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Brand.hull.opacity(0.82)))
            .overlay { RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).strokeBorder(Brand.telemetry.opacity(0.25), lineWidth: Theme.stroke) }
    }
}

/// Section header: tracked mono capitals in telemetry.
struct BrandSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased()).font(Brand.label(Theme.size.caption)).tracking(1.4).foregroundStyle(Brand.telemetry)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Designed empty state: a glyph, one line of what is missing, one action.
struct BrandEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var action: (label: String, run: () -> Void)?
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 44, weight: .light)).symbolRenderingMode(.hierarchical)
                .foregroundStyle(Brand.telemetry)
            Text(title).font(Brand.display(Theme.size.sub)).foregroundStyle(Brand.ink)
            Text(message).font(Brand.label(Theme.size.label)).foregroundStyle(Brand.dim).multilineTextAlignment(.center)
            if let action { Button(action.label, action: action.run).buttonStyle(BrandButtonStyle()) }
        }
        .padding(28)
        .frame(maxWidth: 420)
        .accessibilityElement(children: .combine)
    }
}

/// Designed loading state: pulsing ignition ring with a caption.
struct BrandLoading: View {
    var caption: String = "Preparing"
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("settings.reduceMotion") private var reduceMotionOverride = false
    private var reduceMotion: Bool { systemReduceMotion || reduceMotionOverride }
    var body: some View {
        VStack(spacing: 12) {
            Circle().strokeBorder(Brand.ignition, lineWidth: 3)
                .frame(width: 44, height: 44)
                .scaleEffect(on && !reduceMotion ? 1.12 : 0.92)
                .opacity(on ? 1 : 0.5)
                .animation(reduceMotion ? .default : .easeInOut(duration: 0.8).repeatForever(), value: on)
            Text(caption.uppercased()).font(Brand.label(Theme.size.caption)).tracking(1.4).foregroundStyle(Brand.dim)
        }
        .onAppear { on = true }
        .accessibilityLabel(caption)
    }
}

/// Designed error state.
struct BrandErrorState: View {
    let title: String
    let message: String
    var retry: (() -> Void)?
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 36)).foregroundStyle(Brand.ignition)
            Text(title).font(Brand.display(Theme.size.sub)).foregroundStyle(Brand.ink)
            Text(message).font(Brand.label(Theme.size.label)).foregroundStyle(Brand.dim).multilineTextAlignment(.center)
            if let retry { Button("Try again", action: retry).buttonStyle(LabSecondaryButtonStyle()) }
        }
        .padding(24)
        .accessibilityElement(children: .combine)
    }
}
