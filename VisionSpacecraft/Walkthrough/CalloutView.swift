import SwiftUI

/// One-line spatial callout: small-caps title, body, optional Learn more, Next / Skip, step dots.
struct CalloutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let w = model.walkthrough
        if let step = w.current {
            card(title: step.title, body: step.body, more: step.more) {
                HStack(spacing: 6) {
                    ForEach(w.steps) { s in
                        Capsule().fill(s.id == step.id ? Brand.ignition : (s.id < step.id ? Color.white : Color.white.opacity(0.25)))
                            .frame(width: s.id == step.id ? 18 : 6, height: 6)
                    }
                }
                Spacer()
                Button("Skip tour") { w.skip() }
                    .buttonStyle(.plain)
                    .font(Brand.label(12))
                    .foregroundStyle(w.stepTime > 20 ? Brand.ignition : Brand.dim)
                if step.manual {
                    Button("Next") { w.next() }.buttonStyle(BrandButtonStyle())
                }
            }
            .id(step.id)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else if let tip = w.rangeTip {
            card(title: tip.title, body: tip.body, more: tip.more) {
                Spacer()
                Button("Got it") { w.dismissTip() }.buttonStyle(BrandButtonStyle(tint: .white))
            }
            .transition(.opacity)
        }
    }

    private func card<Actions: View>(title: String, body: String, more: String,
                                     @ViewBuilder actions: () -> Actions) -> some View {
        @Bindable var w = model.walkthrough
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(Brand.ignition).frame(width: 8, height: 8)
                Text(title).font(Brand.label(13)).tracking(3).foregroundStyle(Brand.ignition)
            }
            Text(body).font(.system(size: 21, weight: .semibold, design: .rounded)).foregroundStyle(Brand.ink)
                .fixedSize(horizontal: false, vertical: true)
            if w.showMore {
                Text(more).font(.system(size: 15)).foregroundStyle(Brand.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
            Button(w.showMore ? "Less" : "Learn more", systemImage: w.showMore ? "chevron.up" : "info.circle") {
                withAnimation(.easeOut(duration: 0.3)) { w.showMore.toggle() }
            }
            .buttonStyle(.plain)
            .font(Brand.label(12))
            .foregroundStyle(Brand.telemetry)
            HStack(spacing: 12, content: actions)
        }
        .padding(22)
        .frame(width: 380, alignment: .leading)
        .background(Brand.space.opacity(0.72), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 1))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .animation(.easeOut(duration: 0.3), value: w.showMore)
    }
}

/// Inline once-only tip for windows (hangar board, code editor).
struct TipBanner: View {
    let tip: TipID
    @Environment(AppModel.self) private var model
    @State private var more = false

    var body: some View {
        if model.walkthrough.shouldShow(tip) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(tip.title).font(Brand.label(11)).tracking(3).foregroundStyle(Brand.ignition)
                    Spacer()
                    Button("Learn more") { withAnimation(.easeOut(duration: 0.3)) { more.toggle() } }
                        .buttonStyle(.plain).font(Brand.label(11)).foregroundStyle(Brand.telemetry)
                    Button { model.walkthrough.markSeen(tip) } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).foregroundStyle(Brand.dim)
                        .accessibilityLabel("Dismiss tip")
                }
                Text(tip.body).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(Brand.ink)
                if more { Text(tip.more).font(.system(size: 13)).foregroundStyle(Brand.dim) }
            }
            .padding(14)
            .background(Brand.space.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Brand.ignition.opacity(0.5), lineWidth: 1))
        }
    }
}
