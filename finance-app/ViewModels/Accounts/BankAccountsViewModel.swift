import Combine
import Foundation

@MainActor
final class BankAccountsViewModel: ObservableObject {
    @Published private(set) var accounts: [BankAccount] = []
    @Published private(set) var totalBalance: Decimal = .zero
    @Published var showAddAccount = false
    @Published var selectedAccount: BankAccount?
    @Published var isBalanceHidden = false
    @Published var showDeleteError = false
    @Published private(set) var deleteErrorMessage = "Сначала удалите все операции по этому счёту".appLocalized

    let formatter: NumberFormatter

    private let accountsService: any BankAccountsServicing
    private let transactionsService: any TransactionsServicing
    private let notificationCenter: NotificationCenter
    private var loadRequestID = UUID()
    private var isCreatingAccount = false
    private var updatingAccountIDs: Set<Int> = []
    private var deletingAccountIDs: Set<Int> = []
    private var dataChangeCancellable: AnyCancellable?
    private var allAccounts: [BankAccount] = []
    private var selectedCurrency = AppSettings.currentCurrency

    init(
        accountsService: (any BankAccountsServicing)? = nil,
        transactionsService: (any TransactionsServicing)? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        self.accountsService = accountsService ?? BankAccountsService()
        self.transactionsService = transactionsService ?? TransactionsService()
        self.notificationCenter = notificationCenter

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        self.formatter = formatter
    }

    var formattedTotalBalance: String {
        AmountInputFormatter.format(totalBalance, with: formatter)
    }

    func onAppear(currency: AppCurrency? = nil) {
        setCurrency(currency ?? AppSettings.currentCurrency)
        observeDataChanges()
        Task {
            await loadAccounts()
        }
    }

    func onDisappear() {
        dataChangeCancellable = nil
    }

    func setCurrency(_ currency: AppCurrency) {
        guard selectedCurrency != currency else { return }
        selectedCurrency = currency
        selectedAccount = nil
        applyCurrencyFilter()
    }

    func loadAccounts() async {
        let requestID = UUID()
        loadRequestID = requestID
        await transactionsService.synchronizePendingChangesIfNeeded()
        guard loadRequestID == requestID else { return }
        let loadedAccounts = await accountsService.fetchAccounts()
        guard loadRequestID == requestID else { return }
        apply(loadedAccounts)
    }

    func createAccount(_ account: BankAccount) async {
        guard !isCreatingAccount else { return }
        isCreatingAccount = true
        defer { isCreatingAccount = false }

        _ = await accountsService.createAccount(account)
        await loadAccounts()
    }

    func adjustBalance(for account: BankAccount, newAmount: Decimal, newDate: Date) async {
        guard updatingAccountIDs.insert(account.id).inserted else { return }
        defer { updatingAccountIDs.remove(account.id) }

        let updatedAccount = BankAccount(
            id: account.id,
            userId: account.userId,
            name: account.name,
            emoji: account.emoji,
            balance: newAmount,
            currency: account.currency,
            createdAt: account.createdAt,
            updatedAt: ISO8601DateFormatter().string(from: newDate)
        )

        _ = await accountsService.updateAccount(updatedAccount)
        await loadAccounts()
        selectedAccount = nil
    }

    func deleteAccount(id: Int) async {
        guard deletingAccountIDs.insert(id).inserted else { return }
        defer { deletingAccountIDs.remove(id) }

        let transactions = await transactionsService.fetchTransactionsForAccount(id: id)
        guard transactions.isEmpty else {
            presentDeleteError("Сначала удалите все операции по этому счёту".appLocalized)
            selectedAccount = nil
            return
        }

        let result = await accountsService.deleteAccount(id: id)
        switch result {
        case .deleted:
            apply(allAccounts.filter { $0.id != id })
        case .hasTransactions:
            presentDeleteError("Сначала удалите все операции по этому счёту".appLocalized)
        case .failed:
            presentDeleteError("Произошла ошибка. Попробуйте ещё раз".appLocalized)
        }
        selectedAccount = nil
    }

    private func apply(_ accounts: [BankAccount]) {
        allAccounts = accounts
        applyCurrencyFilter()
    }

    private func applyCurrencyFilter() {
        accounts = allAccounts.filter { $0.currency == selectedCurrency.rawValue }
        totalBalance = accounts.reduce(.zero) { $0 + $1.balance }
    }

    private func presentDeleteError(_ message: String) {
        deleteErrorMessage = message
        showDeleteError = true
    }

    private func observeDataChanges() {
        guard dataChangeCancellable == nil else { return }
        dataChangeCancellable = Publishers.Merge(
            notificationCenter.publisher(for: .transactionsDidChange),
            notificationCenter.publisher(for: .accountsDidChange)
        )
        .sink { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.loadAccounts()
            }
        }
    }
}
