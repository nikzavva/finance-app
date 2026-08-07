import XCTest
@testable import finance_app

final class TransactionTests: XCTestCase {
    func testTransactionStoresAllFields() {
        let date = ISO8601DateFormatter().date(from: "2026-07-11T14:56:59Z")!
        let transaction = Transaction(
            id: 1,
            accountId: 2,
            categoryId: 3,
            amount: Decimal(string: "150.50")!,
            transactionDate: date,
            comment: "Test",
            createdAt: "2026-07-11T14:56:59Z",
            updatedAt: "2026-07-11T14:56:59Z",
            direction: .income
        )

        XCTAssertEqual(transaction.id, 1)
        XCTAssertEqual(transaction.accountId, 2)
        XCTAssertEqual(transaction.categoryId, 3)
        XCTAssertEqual(transaction.amount, Decimal(string: "150.50"))
        XCTAssertEqual(transaction.transactionDate, date)
        XCTAssertEqual(transaction.comment, "Test")
        XCTAssertEqual(transaction.direction, .income)
    }

    func testTransactionPeriodQueryCoversLocalDayAcrossUTCBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 3 * 60 * 60)!
        let startDate = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 2)
        )!
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!

        let query = TransactionPeriodQuery(from: startDate, to: endDate)

        XCTAssertEqual(query.startDate, "2026-08-01")
        XCTAssertEqual(query.endDate, "2026-08-03")
    }

    func testAmountParserAcceptsInteger() {
        XCTAssertEqual(AmountTextField.parseAmount("150"), Decimal(150))
    }

    func testAmountParserTreatsEmptyValueAsZero() {
        XCTAssertEqual(AmountTextField.parseAmount(""), Decimal.zero)
    }

    func testAmountInputFormatterAcceptsLocalizedDecimal() {
        let separator = Locale.current.decimalSeparator ?? ","
        XCTAssertEqual(
            AmountInputFormatter.parse("1 250\(separator)50"),
            Decimal(string: "1250.50")
        )
    }

    @MainActor
    func testFinanceAppViewModelKeepsCategorySelectionPerDirection() async {
        let viewModel = FinanceAppViewModel()
        let income = Category(id: 1, name: "Зарплата", emoji: "💰", isIncome: true)
        let outcome = Category(id: 2, name: "Продукты", emoji: "🍎", isIncome: false)

        viewModel.selectCategory(income, for: .income)
        viewModel.selectCategory(outcome, for: .outcome)

        XCTAssertEqual(viewModel.incomeCategory, income)
        XCTAssertEqual(viewModel.outcomeCategory, outcome)

        viewModel.selectCategory(income, for: .income)

        XCTAssertNil(viewModel.incomeCategory)
        XCTAssertEqual(viewModel.outcomeCategory, outcome)
    }

    @MainActor
    func testAccountsLoadSynchronizesPendingTransactionsBeforeFetchingAccounts() async {
        let recorder = ServiceCallRecorder()
        let viewModel = BankAccountsViewModel(
            accountsService: BankAccountsServiceLoadStub(recorder: recorder),
            transactionsService: TransactionsServiceSyncStub(recorder: recorder)
        )

        await viewModel.loadAccounts()
        let calls = await recorder.snapshot()

        XCTAssertEqual(calls, ["transactions", "accounts"])
    }

    @MainActor
    func testCategorySelectionViewModelSearchesByEveryWord() async {
        let categories = [
            Category(id: 1, name: "Проценты по вкладам", emoji: "🏦", isIncome: true),
            Category(id: 2, name: "Возврат долга", emoji: "🔄", isIncome: true)
        ]
        let viewModel = CategorySelectionViewModel(
            direction: .income,
            categoriesService: CategoriesServiceStub(categories: categories)
        )

        await viewModel.load()
        viewModel.searchText = "про вклад"

        XCTAssertEqual(viewModel.filteredCategories.map(\.id), [1])
    }

    @MainActor
    func testAppLaunchViewModelDefersMigrationErrorUntilSplashFinishes() async {
        let storageManager = StorageManagerSpy(error: TestError.failed)
        let viewModel = AppLaunchViewModel(storageManager: storageManager)

        await viewModel.prepare()

        XCTAssertTrue(viewModel.isReady)
        XCTAssertFalse(viewModel.showMigrationError)

        viewModel.splashDidFinish()

        XCTAssertTrue(viewModel.isSplashFinished)
        XCTAssertTrue(viewModel.showMigrationError)
    }

    @MainActor
    func testAnalyticsPeriodMovesEndWhenStartBecomesLater() async {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let initialStart = calendar.date(byAdding: .day, value: -10, to: today)!
        let initialEnd = calendar.date(byAdding: .day, value: -5, to: today)!
        let editedStart = calendar.date(byAdding: .day, value: -1, to: today)!
        var selectedStart = initialStart
        var selectedEnd = initialEnd
        let viewModel = AnalyticsPeriodFilterViewModel(
            startDate: initialStart,
            endDate: initialEnd,
            customStartDate: initialStart,
            customEndDate: initialEnd,
            calendar: calendar,
            now: { today }
        ) { start, end, _ in
            selectedStart = start
            selectedEnd = end
        }

        viewModel.startDateChanged(to: editedStart)

        XCTAssertTrue(calendar.isDate(selectedStart, inSameDayAs: editedStart))
        XCTAssertTrue(calendar.isDate(selectedEnd, inSameDayAs: editedStart))
    }

    @MainActor
    func testAnalyticsPeriodMovesStartWhenEndBecomesEarlier() async {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let initialStart = calendar.date(byAdding: .day, value: -10, to: today)!
        let initialEnd = calendar.date(byAdding: .day, value: -5, to: today)!
        let editedEnd = calendar.date(byAdding: .day, value: -20, to: today)!
        var selectedStart = initialStart
        var selectedEnd = initialEnd
        let viewModel = AnalyticsPeriodFilterViewModel(
            startDate: initialStart,
            endDate: initialEnd,
            customStartDate: initialStart,
            customEndDate: initialEnd,
            calendar: calendar,
            now: { today }
        ) { start, end, _ in
            selectedStart = start
            selectedEnd = end
        }

        viewModel.endDateChanged(to: editedEnd)

        XCTAssertTrue(calendar.isDate(selectedStart, inSameDayAs: editedEnd))
        XCTAssertTrue(calendar.isDate(selectedEnd, inSameDayAs: editedEnd))
    }

    @MainActor
    func testReducingIncomeBelowAvailableBalanceIsRejected() async {
        let current = makeTransaction(amount: 2000)
        let updated = makeTransaction(amount: 500)
        let transactionsStorage = TransactionsStorageSpy(transaction: current)
        let accountsStorage = AccountsStorageSpy(account: makeAccount(balance: 0))
        let service = TransactionsService(
            transactionsStorageProvider: { transactionsStorage },
            accountsStorageProvider: { accountsStorage }
        )

        let result = await service.updateTransaction(updated)

        guard case .insufficientFunds = result else {
            XCTFail("Ожидалась ошибка недостатка средств")
            return
        }
        let storedAmount = transactionsStorage.transaction.amount
        let storedBalance = accountsStorage.account.balance
        XCTAssertEqual(storedAmount, 2000)
        XCTAssertEqual(storedBalance, 0)
        XCTAssertEqual(transactionsStorage.updateCallCount, 0)
        XCTAssertEqual(accountsStorage.updateCallCount, 0)
        XCTAssertFalse(NetworkActivity.shared.isLoading)
    }

    func testIncomeReductionToZeroProjectedBalanceIsAllowed() {
        let current = makeTransaction(amount: 2000)
        let updated = makeTransaction(amount: 500)

        XCTAssertTrue(
            TransactionBalanceValidator.hasSufficientFunds(
                replacing: current,
                with: updated,
                accountBalances: [1: 1500]
            )
        )
    }

    func testMovingExpenseChecksBothAccounts() {
        let current = makeTransaction(accountId: 1, amount: 1000, direction: .outcome)
        let updated = makeTransaction(accountId: 2, amount: 1000, direction: .outcome)

        XCTAssertFalse(
            TransactionBalanceValidator.hasSufficientFunds(
                replacing: current,
                with: updated,
                accountBalances: [1: 0, 2: 500]
            )
        )
    }

    @MainActor
    func testCreatingExpenseWithoutAccountIsRejected() async {
        let transactionsStorage = TransactionsStorageSpy(transaction: makeTransaction(amount: 1))
        let service = TransactionsService(
            transactionsStorageProvider: { transactionsStorage },
            accountsStorageProvider: { MissingAccountsStorageSpy() }
        )

        let result = await service.createTransaction(
            makeTransaction(amount: 100, direction: .outcome)
        )

        XCTAssertEqual(result, .accountNotFound)
        XCTAssertEqual(transactionsStorage.createCallCount, 0)
    }

    @MainActor
    func testCreatingExpenseAboveCurrentBalanceIsRejected() async {
        let transactionsStorage = TransactionsStorageSpy(transaction: makeTransaction(amount: 1))
        let accountsStorage = AccountsStorageSpy(account: makeAccount(balance: 500))
        let service = TransactionsService(
            transactionsStorageProvider: { transactionsStorage },
            accountsStorageProvider: { accountsStorage }
        )

        let result = await service.createTransaction(
            makeTransaction(amount: 600, direction: .outcome)
        )

        XCTAssertEqual(result, .insufficientFunds)
        XCTAssertEqual(transactionsStorage.createCallCount, 0)
        XCTAssertEqual(accountsStorage.updateCallCount, 0)
    }

    func testEditingOfflineCreationKeepsCreateAction() {
        XCTAssertEqual(
            BackupActionResolver.resolve(existing: .create, adding: .update),
            .create
        )
    }

    func testDeletingOfflineCreationRemovesPendingAction() {
        XCTAssertNil(
            BackupActionResolver.resolve(existing: .create, adding: .delete)
        )
    }

    func testDeletingPendingUpdateKeepsDeleteAction() {
        XCTAssertEqual(
            BackupActionResolver.resolve(existing: .update, adding: .delete),
            .delete
        )
    }

    private func makeTransaction(
        accountId: Int = 1,
        amount: Decimal,
        direction: Direction = .income
    ) -> Transaction {
        Transaction(
            id: 10,
            accountId: accountId,
            categoryId: direction == .income ? 1 : 7,
            amount: amount,
            transactionDate: Date(),
            comment: nil,
            createdAt: nil,
            updatedAt: nil,
            direction: direction
        )
    }

    private func makeAccount(balance: Decimal) -> BankAccount {
        BankAccount(
            id: 1,
            userId: 1,
            name: "Счёт",
            emoji: "💰",
            balance: balance,
            currency: "RUB",
            createdAt: "",
            updatedAt: ""
        )
    }
}

private enum TestError: Error {
    case failed
}

private final class StorageManagerSpy: StorageManaging {
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func switchStorage(to newType: StorageType) async throws {
        if let error {
            throw error
        }
    }

    func migrateIfNeeded() async throws {
        if let error {
            throw error
        }
    }
}

private final class CategoriesServiceStub: CategoriesServicing {
    private let categories: [finance_app.Category]

    init(categories: [finance_app.Category]) {
        self.categories = categories
    }

    func fetchAllCategories() async -> [finance_app.Category] {
        categories
    }

    func fetchCategories(direction: Direction) async -> [finance_app.Category] {
        categories.filter { $0.direction == direction }
    }
}

private actor ServiceCallRecorder {
    private var calls: [String] = []

    func record(_ call: String) {
        calls.append(call)
    }

    func snapshot() -> [String] {
        calls
    }
}

private final class BankAccountsServiceLoadStub: BankAccountsServicing {
    private let recorder: ServiceCallRecorder

    init(recorder: ServiceCallRecorder) {
        self.recorder = recorder
    }

    func fetchAccounts() async -> [BankAccount] {
        await recorder.record("accounts")
        return []
    }

    func createAccount(_ account: BankAccount) async -> BankAccount {
        account
    }

    func updateAccount(_ account: BankAccount) async -> BankAccount {
        account
    }

    func deleteAccount(id: Int) async -> AccountDeletionResult {
        .deleted
    }
}

private final class TransactionsServiceSyncStub: TransactionsServicing {
    private let recorder: ServiceCallRecorder

    init(recorder: ServiceCallRecorder) {
        self.recorder = recorder
    }

    func synchronizePendingChangesIfNeeded() async {
        await recorder.record("transactions")
    }

    func fetchTransactions(from startDate: Date, to endDate: Date) async -> [Transaction] {
        []
    }

    func fetchTransactionsForAccount(id: Int) async -> [Transaction] {
        []
    }

    func createTransaction(_ transaction: Transaction) async -> TransactionCreationResult {
        .created
    }

    func updateTransaction(_ transaction: Transaction) async -> TransactionUpdateResult {
        .updated
    }

    func deleteTransaction(id: Int) async -> TransactionDeletionResult {
        .deleted
    }
}

private final class TransactionsStorageSpy: TransactionsStorage {
    var transaction: Transaction
    private(set) var createCallCount = 0
    private(set) var updateCallCount = 0

    init(transaction: Transaction) {
        self.transaction = transaction
    }

    func fetchAll() async throws -> [Transaction] {
        [transaction]
    }

    func fetch(byIds ids: [Int]) async throws -> [Transaction] {
        ids.contains(transaction.id) ? [transaction] : []
    }

    func create(_ transaction: Transaction) async throws {
        createCallCount += 1
        self.transaction = transaction
    }

    func update(_ transaction: Transaction) async throws {
        updateCallCount += 1
        self.transaction = transaction
    }

    func delete(byId id: Int) async throws {}

    func deleteAll() async throws {}
}

private final class MissingAccountsStorageSpy: AccountsStorage {
    func fetchAll() async throws -> [BankAccount] { [] }
    func fetch(byId id: Int) async throws -> BankAccount? { nil }
    func create(_ account: BankAccount) async throws {}
    func update(_ account: BankAccount) async throws {}
    func delete(byId id: Int) async throws {}
    func deleteAll() async throws {}
}

private final class AccountsStorageSpy: AccountsStorage {
    var account: BankAccount
    private(set) var updateCallCount = 0

    init(account: BankAccount) {
        self.account = account
    }

    func fetchAll() async throws -> [BankAccount] {
        [account]
    }

    func fetch(byId id: Int) async throws -> BankAccount? {
        id == account.id ? account : nil
    }

    func create(_ account: BankAccount) async throws {}

    func update(_ account: BankAccount) async throws {
        updateCallCount += 1
        self.account = account
    }

    func delete(byId id: Int) async throws {}

    func deleteAll() async throws {}
}
