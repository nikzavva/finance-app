import Foundation
import SwiftData

final class AccountsSwiftDataStorage: AccountsStorage {
    private let container: ModelContainer
    
    init(container: ModelContainer) {
        self.container = container
    }
    
    func fetchAll() async throws -> [BankAccount] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AccountEntity>()
        let entities = try context.fetch(descriptor)
        return entities.map { $0.toDomain() }
    }
    
    func fetch(byId id: Int) async throws -> BankAccount? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AccountEntity>()
        let all = try context.fetch(descriptor)
        return all.first(where: { $0.id == id })?.toDomain()
    }
    
    func create(_ account: BankAccount) async throws {
        let context = ModelContext(container)
        let entity = AccountEntity(account: account)
        context.insert(entity)
        try context.save()
    }
    
    func update(_ account: BankAccount) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AccountEntity>()
        let all = try context.fetch(descriptor)
        
        if let existing = all.first(where: { $0.id == account.id }) {
            existing.userId = account.userId
            existing.name = account.name
            existing.emoji = account.emoji
            existing.balance = account.balance
            existing.currency = account.currency
            existing.createdAt = account.createdAt
            existing.updatedAt = account.updatedAt
        } else {
            let entity = AccountEntity(account: account)
            context.insert(entity)
        }
        
        try context.save()
    }
    
    func delete(byId id: Int) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AccountEntity>()
        let all = try context.fetch(descriptor)
        
        guard let existing = all.first(where: { $0.id == id }) else { return }
        context.delete(existing)
        try context.save()
    }
    
    func deleteAll() async throws {
        let context = ModelContext(container)
        try context.delete(model: AccountEntity.self)
        try context.save()
    }
}
