import SwiftUI

struct SpoilerView<Content: View>: View {
    let isHidden: Bool
    let content: Content

    init(isHidden: Bool, @ViewBuilder content: () -> Content) {
        self.isHidden = isHidden
        self.content = content()
    }

    var body: some View {
        content
            .blur(radius: isHidden ? UIConstants.Effects.hiddenBalanceBlurRadius : .zero)
            .animation(
                .easeInOut(duration: UIConstants.Animation.hiddenBalanceDuration),
                value: isHidden
            )
    }
}
