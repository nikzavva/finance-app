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

    private let categoriesService: CategoriesServicing

    private let notificationCenter: NotificationCenter

    private var transactionsLoadTask: Task<Void, Never>?

    private var categoriesLoadTask: Task<Void, Never>?

    private var transactionsChangeCancellable: AnyCancellable?

    private var selectedDate = Date()

    private var selectedCategory: Category?

    init(
        direction: Direction,
        transactionsService: TransactionsServicing? = nil,
        categoriesService: CategoriesServicing? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        self.direction = direction
        self.transactionsService = transactionsService ?? TransactionsService()
        self.categoriesService = categoriesService ?? CategoriesService()
        self.notificationCenter = notificationCenter

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        self.formatter = formatter
    }

    var formattedTotalAmount: String {
        AmountInputFormatter.format(totalAmount, with: formatter) + " ₽"
    }

    var totalTitle: String {
        direction == .income ? "доходы, всего" : "расходы, всего"
    }

    func category(for transaction: Transaction) -> Category? {
        categories.first { $0.id == transaction.categoryId }
    }

    func onAppear(selectedDate: Date, selectedCategory: Category?) {
        observeTransactionChanges()
        loadCategories()
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

        transactionsLoadTask?.cancel()
        transactionsLoadTask = Task { [weak self] in
            guard let self else { return }
            let all = await transactionsService.fetchTransactions(from: startOfDay, to: endOfDay)
            guard !Task.isCancelled else { return }

            let filtered = all.filter { transaction in
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
