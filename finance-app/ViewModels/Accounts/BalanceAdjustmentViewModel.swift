import Combine
import Foundation

@MainActor
final class BalanceAdjustmentViewModel: ObservableObject {
    @Published var amount: String
    @Published var previousAmount: String
    @Published var date = Date()
    @Published var showDeleteConfirmation = false
    @Published private(set) var isSubmitting = false

    private let accountID: Int

    init(account: BankAccount, formatter: NumberFormatter) {
        accountID = account.id
        let initialAmount = AmountInputFormatter.format(account.balance, with: formatter)
        amount = initialAmount
        previousAmount = initialAmount
    }

    func submitBalance() -> (amount: Decimal, date: Date)? {
        guard !isSubmitting else { return nil }
        guard let decimalAmount = AmountInputFormatter.parse(amount) else { return nil }
        isSubmitting = true
        return (decimalAmount, date)
    }

    func requestDeletion() {
        guard !isSubmitting else { return }
        showDeleteConfirmation = true
    }

    func confirmDeletion() -> Int? {
        guard !isSubmitting else { return nil }
        isSubmitting = true
        return accountID
    }
}
