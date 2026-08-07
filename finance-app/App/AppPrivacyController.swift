import UIKit

@MainActor
enum AppPrivacyController {
    static func setProtected(_ isProtected: Bool) {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { !$0.isHidden }

        if isProtected {
            windows.forEach(addPrivacyBlur)
        } else {
            windows.forEach(removePrivacyBlur)
        }
    }

    private static func addPrivacyBlur(to window: UIWindow) {
        guard !window.subviews.contains(where: { $0 is PrivacyBlurView }) else { return }
        let blurView = PrivacyBlurView(effect: UIBlurEffect(style: .systemMaterial))
        blurView.frame = window.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.isUserInteractionEnabled = false
        blurView.contentView.backgroundColor = UIColor.systemBackground.withAlphaComponent(
            UIConstants.Effects.privacyBackgroundOpacity
        )
        window.addSubview(blurView)
        window.bringSubviewToFront(blurView)
        window.layoutIfNeeded()
    }

    private static func removePrivacyBlur(from window: UIWindow) {
        window.subviews
            .filter { $0 is PrivacyBlurView }
            .forEach { $0.removeFromSuperview() }
    }
}

private final class PrivacyBlurView: UIVisualEffectView {}
