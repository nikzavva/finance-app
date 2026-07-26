import Foundation
import SwiftData

final class TransactionsSwiftDataStorage: TransactionsStorage {
    private let container: ModelContainer
    
    init(container: ModelContainer) {
        self.container = container
    }
    
    func fetchAll() async throws -> [Transaction] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TransactionEntity>()
        let entities = try context.fetch(descriptor)
        return entities.map { $0.toDomain() }
    }
    
    func fetch(byIds ids: [Int]) async throws -> [Transaction] {
        let descriptor = FetchDescriptor<TransactionEntity>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        let results = try container.mainContext.fetch(descriptor)
        return results.map { $0.toDomain() }
    }
    
    func create(_ transaction: Transaction) async throws {
        let context = ModelContext(container)
        let entity = TransactionEntity(transaction: transaction)
        context.insert(entity)
        try context.save()
    }
    
    func update(_ transaction: Transaction) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TransactionEntity>()
        let all = try context.fetch(descriptor)
        
        if let existing = all.first(where: { $0.id == transaction.id }) {
            existing.accountId = transaction.accountId
            existing.categoryId = transaction.categoryId
            existing.amount = transaction.amount
            existing.transactionDate = transaction.transactionDate
            existing.comment = transaction.comment
            existing.createdAt = transaction.createdAt
            existing.updatedAt = transaction.updatedAt
            existing.directionRaw = transaction.direction.rawValue
        } else {
            let entity = TransactionEntity(transaction: transaction)
            context.insert(entity)
        }
        
        try context.save()
    }
    
    func delete(byId id: Int) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TransactionEntity>()
        let all = try context.fetch(descriptor)
        
        guard let existing = all.first(where: { $0.id == id }) else { return }
        context.delete(existing)
        try context.save()
    }
    
    func deleteAll() async throws {
        let context = ModelContext(container)
        try context.delete(model: TransactionEntity.self)
        try context.save()
    }
}
