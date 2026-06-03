import SwiftUI

// Dynamic Type for our fixed design sizes. UIFontMetrics scales each base size
// to the user's preferred content size; reading the environment makes SwiftUI
// re-render live when the setting changes. The app root caps the range so the
// tuned Workshop Ledger layout never breaks at the largest accessibility sizes.

private struct ScaledFont: ViewModifier {
    @Environment(\.sizeCategory) private var sizeCategory
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        let scaled = UIFontMetrics.default.scaledValue(for: size)
        return content.font(.system(size: scaled, weight: weight, design: design))
    }
}

extension View {
    func appFont(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design))
    }
}
