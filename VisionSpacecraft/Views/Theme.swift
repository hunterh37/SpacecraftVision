import SwiftUI
import LabUI

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

/// Capsule tab strip matching the CodeWorkspace Blocks / Python / Trace switcher.
struct LabTabs<T: Hashable & Identifiable>: View {
    let items: [T]
    @Binding var selection: T
    let title: (T) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { t in
                Button(title(t)) { selection = t }
                    .buttonStyle(.plain).font(Lab.soft(13)).foregroundStyle(selection == t ? Lab.ink : Lab.muted)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Capsule().fill(selection == t ? Lab.edge.opacity(0.25) : .clear))
                    .contentShape(Capsule())
            }
        }
        .padding(3)
        .background(Capsule().fill(Color(red: 0.02, green: 0.03, blue: 0.14).opacity(0.7)))
        .overlay { Capsule().stroke(Lab.edge.opacity(0.25), lineWidth: 1) }
    }
}
