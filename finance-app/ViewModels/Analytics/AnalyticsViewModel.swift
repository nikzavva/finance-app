import Foundation
import PieChart

enum AnalyticsFilter: Int, CaseIterable {
    case direction
    case period
    case sortOrder
    case categories
    case account
}

struct AnalyticsFilterRowViewData {
    let title: String
    let value: String
}

struct AnalyticsTransactionRowViewData {
    let emoji: String
    let title: String
    let amount: String
}

@MainActor
final class AnalyticsViewModel {
    enum Change {
        case loading
        case filters
        case content
    }

    private struct Filters {
        var direction: Direction?
        var startDate: Date
        var endDate: Date
        var customStartDate: Date
        var customEndDate: Date
        var categoryIDs: Set<Int>?
        var accountID: Int?
        var sortOrder: SortOrder
    }

    private let transactionsService: TransactionsServicing
    private let categoriesService: CategoriesServicing
    private let accountsService: BankAccountsServicing
    private let calendar: Calendar
    private var filters: Filters
    private var transactions: [Transaction] = []
    private var categories: [Category] = []
    private var accounts: [BankAccount] = []
    private var transactionsObserver: NSObjectProtocol?
    private var transactionsTask: Task<Void, Never>?
    private var filterOptionsTask: Task<Void, Never>?
    private var hasStarted = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private(set) var chartEntities: [Entity] = []
    private(set) var transactionRows: [AnalyticsTransactionRowViewData] = []
    private(set) var isLoading = false
    var onChange: ((Change) -> Void)?

    init(
        initialDirection: Direction,
        transactionsService: TransactionsServicing,
        categoriesService: CategoriesServicing,
        accountsService: BankAccountsServicing,
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        self.transactionsService = transactionsService
        self.categoriesService = categoriesService
        self.accountsService = accountsService
        self.calendar = calendar
        let today = calendar.startOfDay(for: now)
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: today) ?? today
        filters = Filters(
            direction: initialDirection,
            startDate: calendar.startOfDay(for: monthAgo),
            endDate: today,
            customStartDate: calendar.startOfDay(for: monthAgo),
            customEndDate: today,
            categoryIDs: nil,
            accountID: nil,
            sortOrder: .date
        )
    }

    deinit {
        transactionsTask?.cancel()
        filterOptionsTask?.cancel()
        if let transactionsObserver {
            NotificationCenter.default.removeObserver(transactionsObserver)
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        observeTransactionChanges()
        loadFilterOptions()
        loadTransactions()
    }

    func stop() {
        transactionsTask?.cancel()
        filterOptionsTask?.cancel()
        transactionsTask = nil
        filterOptionsTask = nil
        if let transactionsObserver {
            NotificationCenter.default.removeObserver(transactionsObserver)
            self.transactionsObserver = nil
        }
        hasStarted = false
        isLoading = false
        onChange = nil
    }

    func filterRow(for filter: AnalyticsFilter) -> AnalyticsFilterRowViewData {
        AnalyticsFilterRowViewData(
            title: filterTitle(for: filter),
            value: filterValue(for: filter)
        )
    }

    func makeDirectionViewModel() -> AnalyticsDirectionFilterViewModel {
        AnalyticsDirectionFilterViewModel(selectedDirection: filters.direction) { [weak self] direction in
            self?.applyDirection(direction)
        }
    }

    func makePeriodViewModel() -> AnalyticsPeriodFilterViewModel {
        AnalyticsPeriodFilterViewModel(
            startDate: filters.startDate,
            endDate: filters.endDate,
            customStartDate: filters.customStartDate,
            customEndDate: filters.customEndDate,
            calendar: calendar
        ) { [weak self] startDate, endDate, isCustom in
            self?.applyPeriod(startDate: startDate, endDate: endDate, isCustom: isCustom)
        }
    }

    func makeSortOrderViewModel() -> AnalyticsSortOrderFilterViewModel {
        AnalyticsSortOrderFilterViewModel(selectedSortOrder: filters.sortOrder) { [weak self] sortOrder in
            self?.applySortOrder(sortOrder)
        }
    }

    func makeCategoriesViewModel() -> AnalyticsCategoriesFilterViewModel {
        let availableCategories: [Category]
        if let direction = filters.direction {
            availableCategories = categories.filter { $0.direction == direction }
        } else {
            availableCategories = categories
        }
        return AnalyticsCategoriesFilterViewModel(
            categories: availableCategories,
            selectedCategoryIDs: filters.categoryIDs
        ) { [weak self] categoryIDs in
            self?.applyCategories(categoryIDs)
        }
    }

    func makeAccountsViewModel() -> AnalyticsAccountsFilterViewModel {
        AnalyticsAccountsFilterViewModel(
            accounts: accounts,
            selectedAccountID: filters.accountID
        ) { [weak self] accountID in
            self?.applyAccount(accountID)
        }
    }

    private func observeTransactionChanges() {
        transactionsObserver = NotificationCenter.default.addObserver(
            forName: .transactionsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadTransactions()
            }
        }
    }

    private func loadFilterOptions() {
        filterOptionsTask?.cancel()
        let categoriesService = self.categoriesService
        let accountsService = self.accountsService
        filterOptionsTask = Task { [weak self] in
            async let fetchedCategories = categoriesService.fetchAllCategories()
            async let fetchedAccounts = accountsService.fetchAccounts()
            let (loadedCategories, loadedAccounts) = await (fetchedCategories, fetchedAccounts)
            guard !Task.isCancelled, let self else { return }
            categories = loadedCategories
            accounts = loadedAccounts
            rebuildPresentation()
            onChange?(.filters)
            onChange?(.content)
        }
    }

    private func loadTransactions() {
        transactionsTask?.cancel()
        setLoading(true)
        let startDate = filters.startDate
        let endDate = calendar.date(byAdding: .day, value: 1, to: filters.endDate) ?? filters.endDate
        let direction = filters.direction
        let categoryIDs = filters.categoryIDs
        let accountID = filters.accountID
        let sortOrder = filters.sortOrder
        let transactionsService = self.transactionsService

        transactionsTask = Task { [weak self] in
            let loadedTransactions = await transactionsService.fetchTransactions(from: startDate, to: endDate)
            guard !Task.isCancelled, let self else { return }
            transactions = loadedTransactions
                .filter { direction == nil || $0.direction == direction }
                .filter { categoryIDs?.contains($0.categoryId) ?? true }
                .filter { accountID == nil || $0.accountId == accountID }
                .sorted { first, second in
                    switch sortOrder {
                    case .date:
                        return first.transactionDate > second.transactionDate
                    case .amount:
                        return first.amount > second.amount
                    }
                }
            rebuildPresentation()
            setLoading(false)
            onChange?(.content)
        }
    }

    private func applyDirection(_ direction: Direction?) {
        guard filters.direction != direction else { return }
        filters.direction = direction
        filters.categoryIDs = nil
        onChange?(.filters)
        loadTransactions()
    }

    private func applyPeriod(startDate: Date, endDate: Date, isCustom: Bool) {
        let normalizedStartDate = calendar.startOfDay(for: startDate)
        let normalizedEndDate = calendar.startOfDay(for: endDate)
        guard filters.startDate != normalizedStartDate || filters.endDate != normalizedEndDate else {
            if isCustom {
                filters.customStartDate = normalizedStartDate
                filters.customEndDate = normalizedEndDate
            }
            return
        }
        filters.startDate = normalizedStartDate
        filters.endDate = normalizedEndDate
        if isCustom {
            filters.customStartDate = normalizedStartDate
            filters.customEndDate = normalizedEndDate
        }
        onChange?(.filters)
        loadTransactions()
    }

    private func applySortOrder(_ sortOrder: SortOrder) {
        guard filters.sortOrder != sortOrder else { return }
        filters.sortOrder = sortOrder
        onChange?(.filters)
        loadTransactions()
    }

    private func applyCategories(_ categoryIDs: Set<Int>?) {
        filters.categoryIDs = categoryIDs
        onChange?(.filters)
        loadTransactions()
    }

    private func applyAccount(_ accountID: Int?) {
        guard filters.accountID != accountID else { return }
        filters.accountID = accountID
        onChange?(.filters)
        loadTransactions()
    }

    private func setLoading(_ isLoading: Bool) {
        guard self.isLoading != isLoading else { return }
        self.isLoading = isLoading
        onChange?(.loading)
    }

    private func rebuildPresentation() {
        let categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        transactionRows = transactions.map { transaction in
            let category = categoriesByID[transaction.categoryId]
            let amount = amountFormatter.string(from: transaction.amount as NSDecimalNumber) ?? "0"
            return AnalyticsTransactionRowViewData(
                emoji: String(category?.emoji ?? "💳"),
                title: transaction.comment ?? "Без описания",
                amount: "\(amount) ₽"
            )
        }

        let groupedTransactions = Dictionary(grouping: transactions, by: \.categoryId)
        chartEntities = groupedTransactions.map { categoryID, categoryTransactions in
            let value = categoryTransactions.reduce(Decimal.zero) { $0 + $1.amount }
            let label = categoriesByID[categoryID]?.name ?? "Без статьи"
            return Entity(value: value, label: label)
        }
        .sorted { first, second in
            if first.value == second.value {
                return first.label.localizedCaseInsensitiveCompare(second.label) == .orderedAscending
            }
            return first.value > second.value
        }
    }

    private func filterTitle(for filter: AnalyticsFilter) -> String {
        switch filter {
        case .direction:
            return "Тип"
        case .period:
            return "Период"
        case .sortOrder:
            return "Сортировка"
        case .categories:
            return "Статьи"
        case .account:
            return "Счёт"
        }
    }

    private func filterValue(for filter: AnalyticsFilter) -> String {
        switch filter {
        case .direction:
            switch filters.direction {
            case nil:
                return "Все"
            case .outcome:
                return "Расходы"
            case .income:
                return "Доходы"
            }
        case .period:
            return "\(dateFormatter.string(from: filters.startDate)) – \(dateFormatter.string(from: filters.endDate))"
        case .sortOrder:
            switch filters.sortOrder {
            case .date:
                return "По дате"
            case .amount:
                return "По сумме"
            }
        case .categories:
            guard let categoryIDs = filters.categoryIDs else { return "Все статьи" }
            let names = categories
                .filter { categoryIDs.contains($0.id) }
                .map(\.name)
            return names.isEmpty ? "Нет статей" : names.joined(separator: ", ")
        case .account:
            guard let accountID = filters.accountID else { return "Все счета" }
            return accounts.first(where: { $0.id == accountID })?.name ?? "Все счета"
        }
    }
}
