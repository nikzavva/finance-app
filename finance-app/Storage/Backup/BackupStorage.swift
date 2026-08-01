import Foundation
import SwiftData

final class BackupStorage {
    private let container: ModelContainer
    
    init(container: ModelContainer) {
        self.container = container
    }
    
    func fetchAllTransactionActions() throws -> [BackupTransactionAction] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BackupTransactionAction>()
        return try context.fetch(descriptor)
    }
    
    func addTransactionAction(_ transaction: Transaction, action: BackupActionType) throws {
        let context = ModelContext(container)
        let all = try context.fetch(FetchDescriptor<BackupTransactionAction>())
        
        if let existing = all.first(where: { $0.transactionId == transaction.id }) {
            context.delete(existing)
        }
        
        let entity = BackupTransactionAction(transaction: transaction, action: action)
        context.insert(entity)
        try context.save()
    }
    
    func removeTransactionAction(byId id: Int) throws {
        let context = ModelContext(container)
        let all = try context.fetch(FetchDescriptor<BackupTransactionAction>())
        
        guard let existing = all.first(where: { $0.transactionId == id }) else { return }
        context.delete(existing)
        try context.save()
    }
    
    func fetchAllAccountActions() throws -> [BackupAccountAction] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BackupAccountAction>()
        return try context.fetch(descriptor)
    }
    
    func addAccountAction(_ account: BankAccount, action: BackupActionType) throws {
        let context = ModelContext(container)
        let all = try context.fetch(FetchDescriptor<BackupAccountAction>())
        
        if let existing = all.first(where: { $0.accountId == account.id }) {
            context.delete(existing)
        }
        
        let entity = BackupAccountAction(account: account, action: action)
        context.insert(entity)
        try context.save()
    }
    
    func removeAccountAction(byId id: Int) throws {
        let context = ModelContext(container)
        let all = try context.fetch(FetchDescriptor<BackupAccountAction>())
        
        guard let existing = all.first(where: { $0.accountId == id }) else { return }
        context.delete(existing)
        try context.save()
    }
}
