import Foundation
import CoreData

final class AccountsCoreDataStorage: AccountsStorage {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    private var fetchRequest: NSFetchRequest<AccountMO> {
        NSFetchRequest<AccountMO>(entityName: "AccountEntity")
    }
    
    func fetchAll() async throws -> [BankAccount] {
        return try context.fetch(fetchRequest).map { $0.toDomain() }
    }
    
    func fetch(byId id: Int) async throws -> BankAccount? {
        let request = fetchRequest
        request.predicate = NSPredicate(format: "id == %lld", Int64(id))
        return try context.fetch(request).first?.toDomain()
    }
    
    func create(_ account: BankAccount) async throws {
        let mo = AccountMO(context: context)
        mo.fill(from: account)
        try CoreDataStack.shared.saveContext()
    }
    
    func update(_ account: BankAccount) async throws {
        let request = fetchRequest
        request.predicate = NSPredicate(format: "id == %lld", Int64(account.id))
        if let existing = try context.fetch(request).first {
            existing.fill(from: account)
        } else {
            let mo = AccountMO(context: context)
            mo.fill(from: account)
        }
        try CoreDataStack.shared.saveContext()
    }
    
    func delete(byId id: Int) async throws {
        let request: NSFetchRequest<AccountMO> = fetchRequest
        request.predicate = NSPredicate(format: "id == %lld", Int64(id))
        if let existing = try context.fetch(request).first {
            context.delete(existing)
            try CoreDataStack.shared.saveContext()
        }
    }
    
    func deleteAll() async throws {
        let results = try context.fetch(fetchRequest)
        results.forEach { context.delete($0) }
        try CoreDataStack.shared.saveContext()
    }
}
