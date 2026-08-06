import Combine
import Foundation

@MainActor
final class CreateAccountViewModel: ObservableObject {
    @Published var name = ""
    @Published var emoji = "💰"
    @Published var amount = "0"
    @Published var previousAmount = "0"
    @Published var date = Date()
    @Published var showValidationError = false
    @Published private(set) var isSubmitting = false

    let popularEmojis = ["💰", "💳", "💵", "💸", "🏦", "🏠", "🚗", "🎒", "📱", "🎯", "🎁", "💼", "🍔", "☕", "🏥", "✈️", "🛒", "💡", "📚", "🎬"]

    func submit() -> BankAccount? {
        guard !isSubmitting else { return nil }
        guard isValid, let decimalAmount = AmountInputFormatter.parse(amount) else {
            showValidationError = true
            return nil
        }

        isSubmitting = true
        let dateString = ISO8601DateFormatter().string(from: date)
        return BankAccount(
            id: 0,
            userId: 0,
            name: name.trimmingCharacters(in: .whitespaces),
            emoji: emoji,
            balance: decimalAmount,
            currency: AppSettings.currentCurrency.rawValue,
            createdAt: dateString,
            updatedAt: dateString
        )
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        AmountInputFormatter.parse(amount) != nil
    }
}
