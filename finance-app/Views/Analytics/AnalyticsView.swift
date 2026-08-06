import SwiftUI
import UIKit

struct AnalyticsView: UIViewControllerRepresentable {
    let initialDirection: Direction

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @EnvironmentObject private var settings: AppSettings

    func makeUIViewController(context: Context) -> UINavigationController {
        let viewModel = AnalyticsViewModel(
            initialDirection: initialDirection,
            transactionsService: TransactionsService(),
            categoriesService: CategoriesService(),
            accountsService: BankAccountsService(),
            currency: settings.currency
        )
        let controller = AnalyticsViewController(viewModel: viewModel) {
            dismiss()
        }
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        _ = locale
        (uiViewController.viewControllers.first as? AnalyticsViewController)?
            .updateLocalization(currency: settings.currency)
    }

    static func dismantleUIViewController(
        _ uiViewController: UINavigationController,
        coordinator: Void
    ) {
        (uiViewController.viewControllers.first as? AnalyticsViewController)?.stop()
    }
}
