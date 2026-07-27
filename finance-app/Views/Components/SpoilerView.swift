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
            .blur(radius: isHidden ? 15 : 0)
            .animation(.easeInOut(duration: 0.25), value: isHidden)
    }
}
