import Combine
import Foundation

@MainActor
final class CreateTransactionViewModel: ObservableObject {
    let direction: Direction
    let currency: AppCurrency
    @Published var amount = "0"
    @Published var previousAmount = "0"
    @Published var date = Date()
    @Published var comment = ""
    @Published var selectedCategory: Category?
    @Published var selectedAccount: BankAccount?
    @Published private(set) var categories: [Category] = []
    @Published private(set) var accounts: [BankAccount] = []
    @Published var showCategorySelection = false
    @Published var showAccountSelection = false
    @Published var showValidationError = false
    @Published var showLoadError = false
    @Published var showSaveError = false
    @Published private(set) var errorMessage = ""
    @Published private(set) var isSaving = false

    private let initialAccount: BankAccount?

    private let transactionsService: TransactionsServicing

    private let accountsService: BankAccountsServicing

    private let categoriesService: CategoriesServicing

    init(
        direction: Direction,
        initialAccount: BankAccount?,
        currency: AppCurrency? = nil,
        transactionsService: TransactionsServicing? = nil,
        accountsService: BankAccountsServicing? = nil,
        categoriesService: CategoriesServicing? = nil
    ) {
        self.direction = direction
        self.initialAccount = initialAccount
        self.currency = initialAccount.flatMap { AppCurrency(rawValue: $0.currency) }
            ?? currency
            ?? AppSettings.currentCurrency
        self.transactionsService = transactionsService ?? TransactionsService()
        self.accountsService = accountsService ?? BankAccountsService()
        self.categoriesService = categoriesService ?? CategoriesService()
    }

    var navigationTitle: String {
        direction == .income ? "Внести доход".appLocalized : "Внести расход".appLocalized
    }

    var validationMessage: String {
        if let amount = AmountInputFormatter.parse(amount),
           let selectedAccount,
           direction == .outcome,
           selectedAccount.balance < amount {
            return "Недостаточно средств на счёте".appLocalized
        }
        return "Сумма должна быть больше 0 и статья обязательна".appLocalized
    }

    func loadInitialData() async {
        async let categoriesTask = categoriesService.fetchCategories(direction: direction)
        async let accountsTask = accountsService.fetchAccounts()

        let (categories, loadedAccounts) = await (categoriesTask, accountsTask)
        guard !Task.isCancelled else { return }

        let accounts = loadedAccounts.filter { $0.currency == currency.rawValue }

        self.categories = categories
        self.accounts = accounts

        if accounts.isEmpty {
            errorMessage = "Сначала создайте счёт в разделе «Счета»".appLocalized
            showLoadError = true
        } else if let initialAccount {
            selectedAccount = initialAccount
        } else {
            selectedAccount = accounts.first
        }
    }

    func openCategorySelection() {
        showCategorySelection = true
    }

    func openAccountSelection() {
        showAccountSelection = true
    }

    func selectCategory(_ category: Category) {
        selectedCategory = category
    }

    func selectAccount(_ account: BankAccount) {
        selectedAccount = account
    }

    func submit() async -> Bool {
        guard !isSaving else { return false }
        guard isValid, let transaction = makeTransaction() else {
            showValidationError = true
            return false
        }

        isSaving = true
        let result = await transactionsService.createTransaction(transaction)
        isSaving = false

        switch result {
        case .created:
            return true
        case .insufficientFunds:
            errorMessage = "Недостаточно средств на счёте".appLocalized
            showSaveError = true
        case .accountNotFound:
            errorMessage = "Выбранный счёт больше недоступен".appLocalized
            showSaveError = true
        case .failed:
            errorMessage = "Не удалось создать операцию".appLocalized
            showSaveError = true
        }
        return false
    }

    private var isValid: Bool {
        guard let amount = AmountInputFormatter.parse(amount),
              amount > 0,
              selectedCategory != nil,
              let selectedAccount else {
            return false
        }

        if direction == .outcome {
            return selectedAccount.balance >= amount
        }
        return true
    }

    private func makeTransaction() -> Transaction? {
        guard let amount = AmountInputFormatter.parse(amount),
              let selectedCategory,
              let selectedAccount else {
            return nil
        }

        return Transaction(
            id: 0,
            accountId: selectedAccount.id,
            categoryId: selectedCategory.id,
            amount: amount,
            transactionDate: date,
            comment: comment.isEmpty ? nil : comment,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            direction: direction
        )
    }
}
