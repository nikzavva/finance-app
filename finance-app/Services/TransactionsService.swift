import Foundation

final class TransactionsService {
    private let cache = TransactionsFileCache(fileName: "transactions_cache")
    
    init() {
        if cache.transactions.isEmpty {
            seedMockData()
        }
    }
    
    func fetchTransactions(from: Date, to: Date) async -> [Transaction] {
        let all = cache.transactions
        return all.filter { $0.transactionDate >= from && $0.transactionDate <= to }
    }
    
    func createTransaction(_ transaction: Transaction) async -> Transaction? {
        var newTransaction = transaction
        newTransaction.id = (cache.transactions.map(\.id).max() ?? 0) + 1
        cache.addTransaction(newTransaction)
        return newTransaction
    }
    func updateTransaction(_ transaction: Transaction) async -> Transaction? {
        cache.addTransaction(transaction)
        return transaction
    }
    
    func deleteTransaction(id: Int) async -> Bool {
        cache.removeTransaction(by: id)
        return true
    }
    
    private func seedMockData() {
        let today = Date()
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: today)
        
        let transactions: [Transaction] = [
            Transaction(id: 1, accountId: 1, categoryId: 1, amount: 1200, transactionDate: today, comment: "Покупка канцтоваров", createdAt: dateString, updatedAt: dateString, direction: .outcome),
            Transaction(id: 2, accountId: 1, categoryId: 2, amount: 1200, transactionDate: today, comment: "Обед в кафе", createdAt: dateString, updatedAt: dateString, direction: .outcome),
            Transaction(id: 3, accountId: 1, categoryId: 3, amount: 1200, transactionDate: today, comment: "Топливо для машины", createdAt: dateString, updatedAt: dateString, direction: .outcome),
            Transaction(id: 4, accountId: 1, categoryId: 4, amount: 1200, transactionDate: today, comment: "Подписка на сервис", createdAt: dateString, updatedAt: dateString, direction: .outcome),
            Transaction(id: 5, accountId: 1, categoryId: 5, amount: 1200, transactionDate: today, comment: "Ремонт техники", createdAt: dateString, updatedAt: dateString, direction: .outcome),
            Transaction(id: 6, accountId: 1, categoryId: 6, amount: 1200, transactionDate: today, comment: "Покупка билетов", createdAt: dateString, updatedAt: dateString, direction: .outcome),
            Transaction(id: 7, accountId: 1, categoryId: 7, amount: 1200, transactionDate: today, comment: "Оплата интернета", createdAt: dateString, updatedAt: dateString, direction: .outcome),
            Transaction(id: 8, accountId: 1, categoryId: 8, amount: 1200, transactionDate: today, comment: "Магазин продуктов", createdAt: dateString, updatedAt: dateString, direction: .outcome),
            Transaction(id: 9, accountId: 1, categoryId: 9, amount: 1200, transactionDate: today, comment: "Продажа старой мебели", createdAt: dateString, updatedAt: dateString, direction: .income),
            Transaction(id: 10, accountId: 1, categoryId: 10, amount: 1200, transactionDate: today, comment: "Возврат налога", createdAt: dateString, updatedAt: dateString, direction: .income),
            Transaction(id: 11, accountId: 1, categoryId: 11, amount: 1200, transactionDate: today, comment: "Премия за проект", createdAt: dateString, updatedAt: dateString, direction: .income),
            Transaction(id: 12, accountId: 1, categoryId: 12, amount: 1200, transactionDate: today, comment: "Подработка фриланс", createdAt: dateString, updatedAt: dateString, direction: .income),
            Transaction(id: 13, accountId: 1, categoryId: 13, amount: 1200, transactionDate: today, comment: "Сдача квартиры", createdAt: dateString, updatedAt: dateString, direction: .income),
            Transaction(id: 14, accountId: 1, categoryId: 14, amount: 1200, transactionDate: today, comment: "Кэшбэк на карту", createdAt: dateString, updatedAt: dateString, direction: .income),
            Transaction(id: 15, accountId: 1, categoryId: 15, amount: 1200, transactionDate: today, comment: "Подарок от родителей", createdAt: dateString, updatedAt: dateString, direction: .income)
        ]
        
        transactions.forEach { cache.addTransaction($0) }
        try? cache.save()
    }
}
