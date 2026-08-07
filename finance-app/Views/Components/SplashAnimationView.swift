import SwiftUI
import FinanceAppDependencies

struct SplashAnimationView: UIViewRepresentable {
    let onFinished: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    func makeUIView(context: Context) -> SplashAnimationPlayerView {
        let animationView = SplashAnimationPlayerView(animationName: "splash_animation")
        HapticsManager.shared.playSplash()

        DispatchQueue.main.async {
            guard animationView.hasAnimation else {
                context.coordinator.finish()
                return
            }
            animationView.play { finished in
                if finished {
                    context.coordinator.finish()
                }
            }
        }

        return animationView
    }

    func updateUIView(_ animationView: SplashAnimationPlayerView, context: Context) {}

    final class Coordinator {
        private let onFinished: () -> Void
        private var hasFinished = false

        init(onFinished: @escaping () -> Void) {
            self.onFinished = onFinished
        }

        func finish() {
            guard !hasFinished else { return }
            hasFinished = true
            HapticsManager.shared.stopSplash()
            onFinished()
        }
    }
}
