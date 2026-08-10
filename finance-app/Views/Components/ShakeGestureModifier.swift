import SwiftUI
import UIKit

struct ShakeGestureModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.background(
            ShakeViewControllerRepresentable(action: action)
        )
    }
}

struct ShakeViewControllerRepresentable: UIViewControllerRepresentable {
    let action: () -> Void

    func makeUIViewController(context: Context) -> ShakeViewController {
        let vc = ShakeViewController()
        vc.action = action
        return vc
    }

    func updateUIViewController(_ uiViewController: ShakeViewController, context: Context) {}
}

class ShakeViewController: UIViewController {
    var action: (() -> Void)?

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            HapticsManager.shared.play(.action)
            action?()
        }
    }

    override var canBecomeFirstResponder: Bool { true }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(ShakeGestureModifier(action: action))
    }
}
