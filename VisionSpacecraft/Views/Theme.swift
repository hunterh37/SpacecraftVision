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
