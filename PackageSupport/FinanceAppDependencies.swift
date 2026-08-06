import Lottie
import UIKit

public final class SplashAnimationPlayerView: UIView {
    private let animationView: LottieAnimationView

    public var hasAnimation: Bool {
        animationView.animation != nil
    }

    public init(animationName: String) {
        animationView = LottieAnimationView(name: animationName)
        super.init(frame: .zero)

        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .playOnce
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.isAccessibilityElement = false
        addSubview(animationView)

        NSLayoutConstraint.activate([
            animationView.topAnchor.constraint(equalTo: topAnchor),
            animationView.leadingAnchor.constraint(equalTo: leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: trailingAnchor),
            animationView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    public required init?(coder: NSCoder) {
        nil
    }

    public func play(completion: @escaping (Bool) -> Void) {
        animationView.play(completion: completion)
    }
}
