import Foundation

final class TransactionsService {
    private let cache = TransactionsFileCache(fileName: "transactions_cache")
    
    func fetchTransactions(from: Date, to: Date) async -> [Transaction] {
        let all = cache.transactions
        return all.filter { $0.transactionDate >= from && $0.transactionDate <= to }
    }
    
    func createTransaction(_ transaction: Transaction) async -> Transaction? {
        cache.addTransaction(transaction)
        return transaction
    }
    
    func updateTransaction(_ transaction: Transaction) async -> Transaction? {
        cache.addTransaction(transaction)
        return transaction
    }
    
    func deleteTransaction(id: Int) async -> Bool {
        cache.removeTransaction(by: id)
        return true
    }
}
