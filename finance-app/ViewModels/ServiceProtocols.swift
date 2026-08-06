import Foundation

protocol TransactionsServicing {
    func synchronizePendingChangesIfNeeded() async
    func fetchTransactions(from startDate: Date, to endDate: Date) async -> [Transaction]
    func fetchTransactionsForAccount(id: Int) async -> [Transaction]
    func createTransaction(_ transaction: Transaction) async -> TransactionCreationResult
    func updateTransaction(_ transaction: Transaction) async -> TransactionUpdateResult
    func deleteTransaction(id: Int) async -> TransactionDeletionResult
}

extension TransactionsServicing {
    func synchronizePendingChangesIfNeeded() async {}
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
