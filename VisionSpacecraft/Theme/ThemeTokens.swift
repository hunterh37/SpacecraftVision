import SwiftUI
import LabUI

/// App-side design tokens layered on `LabUI.Brand` (notes/design/BRAND.md).
enum Theme {
    /// z-offset scale in points.
    enum z { static let flat: CGFloat = 0, card: CGFloat = 8, raised: CGFloat = 24, hero: CGFloat = 48 }
    static let corner: CGFloat = 18
    static let stroke: CGFloat = 1
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.82)
    /// Type scale.
    enum size { static let title: CGFloat = 40, heading: CGFloat = 28, sub: CGFloat = 20, body: CGFloat = 15, label: CGFloat = 13, caption: CGFloat = 11 }
}
