import Foundation
import CoreData

final class TransactionsCoreDataStorage: TransactionsStorage {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    private var fetchRequest: NSFetchRequest<TransactionMO> {
        NSFetchRequest<TransactionMO>(entityName: "TransactionEntity")
    }
    
    func fetchAll() async throws -> [Transaction] {
        let results = try context.fetch(fetchRequest)
        return results.map { $0.toDomain() }
    }
    
    func fetch(byIds ids: [Int]) async throws -> [Transaction] {
        let request: NSFetchRequest<TransactionMO> = fetchRequest
        let id64 = ids.map { Int64($0) }
        request.predicate = NSPredicate(format: "id IN %@", id64)
        let results = try context.fetch(request)
        return results.map { $0.toDomain() }
    }

    func delete(byId id: Int) async throws {
        let request: NSFetchRequest<TransactionMO> = fetchRequest
        request.predicate = NSPredicate(format: "id == %lld", Int64(id))
        if let existing = try context.fetch(request).first {
            context.delete(existing)
            CoreDataStack.shared.saveContext()
        }
    }
    
    func create(_ transaction: Transaction) async throws {
        let mo = TransactionMO(context: context)
        mo.fill(from: transaction)
        CoreDataStack.shared.saveContext()
    }
    
    func update(_ transaction: Transaction) async throws {
        let request = fetchRequest
        request.predicate = NSPredicate(format: "id == %lld", Int64(transaction.id))
        if let existing = try context.fetch(request).first {
            existing.fill(from: transaction)
        } else {
            let mo = TransactionMO(context: context)
            mo.fill(from: transaction)
        }
        CoreDataStack.shared.saveContext()
    }
        
    func deleteAll() async throws {
        let results = try context.fetch(fetchRequest)
        results.forEach { context.delete($0) }
        CoreDataStack.shared.saveContext()
    }
}
