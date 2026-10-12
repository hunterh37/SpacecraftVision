import SwiftUI
import LabUI

extension View {
    /// Brand card chrome on any view.
    func brandCard() -> some View { BrandCard { self } }
    /// Hover lift on tiles: 1.04 scale, brand spring.
    func tileHover() -> some View { hoverEffect(.lift) }
}
