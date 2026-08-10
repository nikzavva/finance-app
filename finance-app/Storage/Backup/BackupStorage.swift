import Foundation
import SwiftData

enum BackupActionResolver {
    static func resolve(existing: BackupActionType?, adding newAction: BackupActionType) -> BackupActionType? {
        guard let existing else { return newAction }

        switch (existing, newAction) {
        case (.create, .update):
            return .create
        case (.create, .delete):
            return nil
        case (.delete, .update):
            return .delete
        default:
            return newAction
        }
    }
}

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
        let existing = all.first(where: { $0.transactionId == transaction.id })
        let resolvedAction = BackupActionResolver.resolve(existing: existing?.actionType, adding: action)

        if let existing {
            context.delete(existing)
        }

        guard let resolvedAction else {
            try context.save()
            return
        }

        let entity = BackupTransactionAction(transaction: transaction, action: resolvedAction)
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
        let existing = all.first(where: { $0.accountId == account.id })
        let resolvedAction = BackupActionResolver.resolve(existing: existing?.actionType, adding: action)

        if let existing {
            context.delete(existing)
        }

        guard let resolvedAction else {
            try context.save()
            return
        }

        let entity = BackupAccountAction(account: account, action: resolvedAction)
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

    func deleteAllActions() throws {
        let context = ModelContext(container)
        try context.delete(model: BackupTransactionAction.self)
        try context.delete(model: BackupAccountAction.self)
        try context.save()
    }
}
