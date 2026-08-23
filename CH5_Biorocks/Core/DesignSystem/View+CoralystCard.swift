import SwiftUI

/// Shared visual treatment for Coralyst cards.
extension View {
    func siteGlassCard(cornerRadius: CGFloat = 16, interactive: Bool = false) -> some View {
        glassEffect(
            .regular.interactive(interactive),
            in: .rect(cornerRadius: cornerRadius)
        )
    }
}
