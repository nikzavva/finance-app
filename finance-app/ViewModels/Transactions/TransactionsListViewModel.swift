import Combine
import Foundation

@MainActor
final class TransactionsListViewModel: ObservableObject {
    let direction: Direction
    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var categories: [Category] = []
    @Published private(set) var totalAmount: Decimal = .zero
    @Published var sortOrder: SortOrder = .date
    @Published var showCreateTransaction = false
    @Published var selectedTransaction: Transaction?

    let formatter: NumberFormatter

    private let transactionsService: TransactionsServicing

    private let accountsService: BankAccountsServicing

    private let categoriesService: CategoriesServicing

    private let notificationCenter: NotificationCenter

    private var transactionsLoadTask: Task<Void, Never>?

    private var categoriesLoadTask: Task<Void, Never>?

    private var transactionsChangeCancellable: AnyCancellable?

    private var selectedDate = Date()

    private var selectedCategory: Category?

    private var selectedCurrency = AppSettings.currentCurrency

    private var isActive = false

    init(
        direction: Direction,
        transactionsService: TransactionsServicing? = nil,
        accountsService: BankAccountsServicing? = nil,
        categoriesService: CategoriesServicing? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        self.direction = direction
        self.transactionsService = transactionsService ?? TransactionsService()
        self.accountsService = accountsService ?? BankAccountsService()
        self.categoriesService = categoriesService ?? CategoriesService()
        self.notificationCenter = notificationCenter

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        self.formatter = formatter
    }

    func formattedTotalAmount(currencySymbol: String) -> String {
        AmountInputFormatter.format(totalAmount, with: formatter) + " \(currencySymbol)"
    }

    func category(for transaction: Transaction) -> Category? {
        categories.first { $0.id == transaction.categoryId }
    }

    func onAppear(
        selectedDate: Date,
        selectedCategory: Category?,
        currency: AppCurrency? = nil
    ) {
        selectedCurrency = currency ?? AppSettings.currentCurrency
        isActive = true
        observeTransactionChanges()
        loadCategories()
        loadTransactions(selectedDate: selectedDate, selectedCategory: selectedCategory)
    }

    func setCurrency(_ currency: AppCurrency) {
        guard selectedCurrency != currency else { return }
        selectedCurrency = currency
        selectedTransaction = nil
        guard isActive else { return }
        loadTransactions(selectedDate: selectedDate, selectedCategory: selectedCategory)
    }

    func showCreateForm() {
        showCreateTransaction = true
    }

    func selectTransaction(_ transaction: Transaction) {
        selectedTransaction = transaction
    }

    func loadCategories() {
        categoriesLoadTask?.cancel()
        categoriesLoadTask = Task { [weak self] in
            guard let self else { return }
            let all = await categoriesService.fetchAllCategories()
            guard !Task.isCancelled else { return }
            categories = all
        }
    }

    func loadTransactions(selectedDate: Date, selectedCategory: Category?) {
        self.selectedDate = selectedDate
        self.selectedCategory = selectedCategory
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            return
        }
        let categoryID = selectedCategory?.id
        let currentSortOrder = sortOrder
        let currentDirection = direction
        let currentCurrency = selectedCurrency
        let accountsService = self.accountsService
        let transactionsService = self.transactionsService

        transactionsLoadTask?.cancel()
        transactionsLoadTask = Task { [weak self] in
            guard let self else { return }
            async let transactionsTask = transactionsService.fetchTransactions(from: startOfDay, to: endOfDay)
            async let accountsTask = accountsService.fetchAccounts()
            let (all, accounts) = await (transactionsTask, accountsTask)
            guard !Task.isCancelled else { return }

            let accountIDs = Set(
                accounts
                    .filter { $0.currency == currentCurrency.rawValue }
                    .map(\.id)
            )

            let filtered = all.filter { transaction in
                accountIDs.contains(transaction.accountId) &&
                transaction.direction == currentDirection &&
                (categoryID == nil || transaction.categoryId == categoryID)
            }

            let sorted: [Transaction]
            switch currentSortOrder {
            case .date:
                sorted = filtered.sorted { $0.transactionDate > $1.transactionDate }
            case .amount:
                sorted = filtered.sorted { $0.amount > $1.amount }
            }

            guard !Task.isCancelled else { return }
            transactions = sorted
            totalAmount = filtered.reduce(.zero) { $0 + $1.amount }
        }
    }

    func cancelLoading() {
        isActive = false
        transactionsLoadTask?.cancel()
        categoriesLoadTask?.cancel()
        transactionsChangeCancellable = nil
    }

    private func observeTransactionChanges() {
        guard transactionsChangeCancellable == nil else { return }
        transactionsChangeCancellable = notificationCenter.publisher(for: .transactionsDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    loadTransactions(
                        selectedDate: selectedDate,
                        selectedCategory: selectedCategory
                    )
                }
            }
    }
}
