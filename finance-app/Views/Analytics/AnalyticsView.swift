import SwiftUI
import UIKit

struct AnalyticsView: UIViewControllerRepresentable {
    let initialDirection: Direction

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UINavigationController {
        let viewModel = AnalyticsViewModel(
            initialDirection: initialDirection,
            transactionsService: TransactionsService(),
            categoriesService: CategoriesService(),
            accountsService: BankAccountsService()
        )
        let controller = AnalyticsViewController(viewModel: viewModel) {
            dismiss()
        }
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    static func dismantleUIViewController(
        _ uiViewController: UINavigationController,
        coordinator: Void
    ) {
        (uiViewController.viewControllers.first as? AnalyticsViewController)?.stop()
    }
}
