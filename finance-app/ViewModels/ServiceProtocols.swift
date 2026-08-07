import Foundation

protocol TransactionsServicing {
    func synchronizePendingChangesIfNeeded() async
    func fetchTransactions(from startDate: Date, to endDate: Date) async -> [Transaction]
    func fetchTransactionsForAccount(id: Int) async -> [Transaction]
    func deleteTransactionsForAccount(id: Int) async -> Bool
    func createTransaction(_ transaction: Transaction) async -> TransactionCreationResult
    func updateTransaction(_ transaction: Transaction) async -> TransactionUpdateResult
    func deleteTransaction(id: Int) async -> TransactionDeletionResult
}

extension TransactionsServicing {
    func synchronizePendingChangesIfNeeded() async {}

    func deleteTransactionsForAccount(id: Int) async -> Bool {
        let transactions = await fetchTransactionsForAccount(id: id).sorted { first, second in
            first.direction == .outcome && second.direction == .income
        }
        for transaction in transactions {
            guard await deleteTransaction(id: transaction.id) == .deleted else { return false }
        }
        return true
    }
}

protocol BankAccountsServicing {
    func fetchAccounts() async -> [BankAccount]
    func createAccount(_ account: BankAccount) async -> BankAccount
    func updateAccount(_ account: BankAccount) async -> BankAccount
    func deleteAccount(id: Int) async -> AccountDeletionResult
}

protocol CategoriesServicing {
    func fetchAllCategories() async -> [Category]
    func fetchCategories(direction: Direction) async -> [Category]
}

protocol StorageManaging {
    func switchStorage(to newType: StorageType) async throws
    func migrateIfNeeded() async throws
}

extension TransactionsService: TransactionsServicing {}
extension BankAccountsService: BankAccountsServicing {}
extension CategoriesService: CategoriesServicing {}
extension StorageManager: StorageManaging {}
