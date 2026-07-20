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
            .overlay {
                if isHidden {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [
                                Color.gray.opacity(0.0),
                                Color.white.opacity(0.6),
                                Color.gray.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: shimmerOffset)
                        .animation(
                            Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                            value: shimmerOffset
                        )
                    }
                    .mask(content)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isHidden)
            .onAppear {
                if isHidden {
                    shimmerOffset = -200
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        shimmerOffset = 200
                    }
                }
            }
    }
    
    @State private var shimmerOffset: CGFloat = -200
}
