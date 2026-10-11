import SwiftUI

/// A screen title in the shared style. Two flavours share one type:
///  - `LabHeader("Title", caption: "Last flight", onBack: ...)`: tracked caption on a short tinted rule, then the display title, with an optional back button.
///  - `LabHeader(kicker: "M1 · Python", title: "Mission")`: mono kicker over an uppercase display title.
public struct LabHeader<Trailing: View>: View {
    public var title: String
    public var caption: String?
    public var kicker: String?
    public var tint: Color
    public var onBack: (() -> Void)?
    @ViewBuilder public var trailing: Trailing

    public init(_ title: String, caption: String? = nil, tint: Color = Brand.telemetry, onBack: (() -> Void)? = nil, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title; self.caption = caption; self.kicker = nil; self.tint = tint; self.onBack = onBack; self.trailing = trailing()
    }

    public init(kicker: String, title: String, tint: Color = Brand.ignition, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title; self.caption = nil; self.kicker = kicker; self.tint = tint; self.onBack = nil; self.trailing = trailing()
    }

    public var body: some View {
        if let kicker {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(kicker.uppercased()).font(Brand.label(12)).tracking(3).foregroundStyle(tint)
                    Text(title.uppercased()).font(Lab.display(24)).foregroundStyle(Lab.ink).lineLimit(1).minimumScaleFactor(0.6)
                }
                Spacer(minLength: 8)
                trailing
            }
        } else {
            HStack(alignment: .bottom, spacing: 14) {
                if let onBack {
                    Button(action: onBack) { Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundStyle(Brand.ink).frame(width: 44, height: 44) }
                        .buttonStyle(.plain)
                        .background(Circle().fill(tint.opacity(0.16))).overlay { Circle().strokeBorder(tint.opacity(0.5), lineWidth: 1) }
                        .lift()
                        .accessibilityLabel("Back")
                }
                VStack(alignment: .leading, spacing: 6) {
                    if let caption {
                        HStack(spacing: 8) {
                            Rectangle().fill(tint).frame(width: 26, height: 3).clipShape(Capsule())
                            Text(caption.uppercased()).font(Brand.label(11)).tracking(2.4).foregroundStyle(tint)
                        }
                    }
                    Text(title).font(Lab.display(26)).foregroundStyle(Brand.ink).lineLimit(2)
                }
                Spacer(minLength: 12)
                trailing
            }
        }
    }
}

/// A list row: index in mono, title and detail, trailing controls, on a quiet tinted card with a left rail.
public struct LabRow<Trailing: View>: View {
    public var index: String
    public var title: String
    public var detail: String
    public var tint: Color
    public var selected = false
    @ViewBuilder public var trailing: Trailing

    public init(index: String, title: String, detail: String, tint: Color, selected: Bool = false, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.index = index; self.title = title; self.detail = detail; self.tint = tint; self.selected = selected; self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: 18) {
            Capsule().fill(tint).frame(width: 4, height: 44).shadow(color: tint.opacity(0.7), radius: 6)
            Text(index).font(Brand.label(16)).foregroundStyle(tint).frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Brand.ink)
                Text(detail).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.white.opacity(0.7))
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 20).padding(.vertical, 18)
        .labCard(corner: 24, tint: tint, variant: .dusk, aurora: selected ? 0.3 : 0.15)
        .overlay { if selected { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(tint, lineWidth: 2) } }
        .hoverShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .lift()
    }
}

/// Stage navigation as numbered dots in a pill: done stages are filled, the current one is named.
public struct LabStagePicker: View {
    public var titles: [String]
    @Binding public var selection: Int
    public var tint: Color

    public init(titles: [String], selection: Binding<Int>, tint: Color = Brand.telemetry) { self.titles = titles; _selection = selection; self.tint = tint }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(titles.enumerated()), id: \.offset) { i, t in
                Button { selection = i } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().fill(i == selection ? tint : i < selection ? tint.opacity(0.35) : Color.white.opacity(0.10)).frame(width: 22, height: 22)
                            if i < selection { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Brand.space) }
                            else { Text("\(i + 1)").font(Brand.label(11)).foregroundStyle(i == selection ? Brand.space : Brand.dim) }
                        }
                        .shadow(color: i == selection ? tint.opacity(0.8) : .clear, radius: 8)
                        if i == selection { Text(t.uppercased()).font(Brand.label(11)).tracking(1.6).foregroundStyle(Brand.ink) }
                    }
                    .padding(.horizontal, i == selection ? 14 : 8).padding(.vertical, 7)
                    .background(Capsule().fill(i == selection ? tint.opacity(0.18) : .clear))
                    .overlay { if i == selection { Capsule().strokeBorder(tint.opacity(0.5), lineWidth: 1) } }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(t), step \(i + 1) of \(titles.count)")
            }
        }
        .padding(4)
        .background(Capsule().fill(Color(red: 0.02, green: 0.03, blue: 0.1).opacity(0.7)))
        .overlay { Capsule().strokeBorder(Lab.edge.opacity(0.25), lineWidth: 1) }
    }
}

/// One labelled value in a stat list: caption left, mono value right, optional marker dot, red when over a limit.
public struct LabStatRow: View {
    public var label: String
    public var value: String
    public var warn = false
    public var dot: Color?
    public init(_ label: String, _ value: String, warn: Bool = false, dot: Color? = nil) { self.label = label; self.value = value; self.warn = warn; self.dot = dot }
    public var body: some View {
        HStack(spacing: 8) {
            if let dot { Circle().fill(dot).frame(width: 9, height: 9).shadow(color: dot, radius: 4) }
            Text(label).font(Brand.label(12)).tracking(0.5).foregroundStyle(Brand.dim)
            Spacer(minLength: 10)
            Text(value).font(Brand.label(14)).monospacedDigit().foregroundStyle(warn ? Lab.danger : Brand.ink)
        }
    }
}

/// An inset dark plate for charts and code: same corner and hairline as the rest, no white backgrounds.
public extension View {
    func labPlate(corner: CGFloat = 16) -> some View {
        background(Color(red: 0.02, green: 0.03, blue: 0.1).opacity(0.72), in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(Lab.edge.opacity(0.2), lineWidth: 1) }
    }
}

public extension View {
    /// Hover-effect outline on visionOS; a no-op where hover effects do not exist.
    @ViewBuilder func hoverShape<S: Shape>(_ shape: S) -> some View {
        #if os(visionOS)
        contentShape(.hoverEffect, shape)
        #else
        contentShape(shape)
        #endif
    }
}
