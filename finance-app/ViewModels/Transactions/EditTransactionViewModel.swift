import Combine
import Foundation

@MainActor
final class EditTransactionViewModel: ObservableObject {
    let transaction: Transaction
    @Published var amount = ""
    @Published var previousAmount = ""
    @Published var date = Date()
    @Published var comment = ""
    @Published var selectedCategory: Category?
    @Published var selectedAccount: BankAccount?
    @Published private(set) var categories: [Category] = []
    @Published private(set) var accounts: [BankAccount] = []
    @Published var showCategorySelection = false
    @Published var showAccountSelection = false
    @Published var showDeleteConfirmation = false
    @Published var showValidationError = false
    @Published private(set) var deletionBlocked = false
    @Published var showSaveError = false
    @Published private(set) var errorMessage = ""
    @Published private(set) var isSaving = false
    @Published private(set) var accountCurrency = AppSettings.currentCurrency

    private let transactionsService: TransactionsServicing

    private let accountsService: BankAccountsServicing

    private let categoriesService: CategoriesServicing

    private let formatter: NumberFormatter

    init(
        transaction: Transaction,
        transactionsService: TransactionsServicing? = nil,
        accountsService: BankAccountsServicing? = nil,
        categoriesService: CategoriesServicing? = nil
    ) {
        self.transaction = transaction
        self.transactionsService = transactionsService ?? TransactionsService()
        self.accountsService = accountsService ?? BankAccountsService()
        self.categoriesService = categoriesService ?? CategoriesService()

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        self.formatter = formatter
    }

    var navigationTitle: String {
        transaction.direction == .income ? "Корректировка дохода".appLocalized : "Корректировка расхода".appLocalized
    }

    var validationTitle: String {
        hasInsufficientFunds ? "Недостаточно средств".appLocalized : "Заполните все поля".appLocalized
    }

    var validationMessage: String {
        hasInsufficientFunds ? "Недостаточно средств на счёте".appLocalized : "Сумма должна быть больше 0".appLocalized
    }

    func loadInitialData() async {
        async let categoriesTask = categoriesService.fetchCategories(direction: transaction.direction)
        async let accountsTask = accountsService.fetchAccounts()

        let (categories, loadedAccounts) = await (categoriesTask, accountsTask)
        guard !Task.isCancelled else { return }

        let initialAccount = loadedAccounts.first { $0.id == transaction.accountId }
        let accountCurrency = initialAccount
            .flatMap { AppCurrency(rawValue: $0.currency) } ?? AppSettings.currentCurrency
        let accounts = loadedAccounts.filter { $0.currency == accountCurrency.rawValue }

        self.categories = categories
        self.accounts = accounts
        self.accountCurrency = accountCurrency
        selectedCategory = categories.first { $0.id == transaction.categoryId }
        selectedAccount = initialAccount

        let initialAmount = AmountInputFormatter.format(transaction.amount, with: formatter)
        amount = initialAmount
        previousAmount = initialAmount
        date = transaction.transactionDate
        comment = transaction.comment ?? ""
    }

    func openCategorySelection() {
        showCategorySelection = true
    }

    func openAccountSelection() {
        showAccountSelection = true
    }

    func requestDeletion() {
        showDeleteConfirmation = true
    }

    func selectCategory(_ category: Category) {
        selectedCategory = category
    }

    func selectAccount(_ account: BankAccount) {
        selectedAccount = account
    }

    func dismissValidationError() {
        deletionBlocked = false
    }

    func submit() async -> Bool {
        guard !isSaving else { return false }
        guard isValid, let updatedTransaction = makeUpdatedTransaction() else {
            deletionBlocked = false
            showValidationError = true
            return false
        }

        isSaving = true
        let result = await transactionsService.updateTransaction(updatedTransaction)
        isSaving = false

        switch result {
        case .updated:
            return true
        case .insufficientFunds:
            deletionBlocked = true
            showValidationError = true
        case .failed:
            errorMessage = "Не удалось сохранить операцию".appLocalized
            showSaveError = true
        }
        return false
    }

    func delete() async -> Bool {
        guard !isSaving else { return false }

        isSaving = true
        let result = await transactionsService.deleteTransaction(id: transaction.id)
        isSaving = false

        switch result {
        case .deleted:
            return true
        case .insufficientFunds:
            deletionBlocked = true
            showValidationError = true
        case .failed:
            errorMessage = "Не удалось удалить операцию".appLocalized
            showSaveError = true
        }
        return false
    }

    private var isValid: Bool {
        guard let updatedTransaction = makeUpdatedTransaction() else { return false }
        return TransactionBalanceValidator.hasSufficientFunds(
            replacing: transaction,
            with: updatedTransaction,
            accountBalances: Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0.balance) })
        )
    }

    private var hasInsufficientFunds: Bool {
        if deletionBlocked {
            return true
        }
        guard let updatedTransaction = makeUpdatedTransaction() else { return false }
        return !TransactionBalanceValidator.hasSufficientFunds(
            replacing: transaction,
            with: updatedTransaction,
            accountBalances: Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0.balance) })
        )
    }

    private func makeUpdatedTransaction() -> Transaction? {
        guard let amount = AmountInputFormatter.parse(amount),
              amount > 0,
              let selectedCategory,
              let selectedAccount else {
            return nil
        }

        return Transaction(
            id: transaction.id,
            accountId: selectedAccount.id,
            categoryId: selectedCategory.id,
            amount: amount,
            transactionDate: date,
            comment: comment.isEmpty ? nil : comment,
            createdAt: transaction.createdAt,
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            direction: transaction.direction
        )
    }
}
