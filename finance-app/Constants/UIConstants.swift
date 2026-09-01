import Foundation
import UIKit

enum UIConstants {
    enum Sizes {
        static let button: CGFloat = 64
        static let icon: CGFloat = 40
        static let totalAmountFontSize: CGFloat = 45
        static let dividerHeight: CGFloat = 1
        static var hairlineWidth: CGFloat { 1 / UIScreen.main.scale }
    }

    enum Spacing {
        static let small: CGFloat = 8
        static let settingsSection: CGFloat = 28
    }

    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
    }

    enum Ratios {
        static let amountDividerWidth: CGFloat = 3 / 4
    }

    enum Effects {
        static let overlayOpacity = 0.2
        static let hiddenBalanceBlurRadius: CGFloat = 15
    }

    enum Animation {
        static let hiddenBalanceDuration = 0.25
        static let balanceSpringResponse = 0.3
        static let balanceSpringDampingFraction = 0.7
    }
}
