import Foundation
import SwiftData
import CoreData

final class StorageManager {
    static let shared = StorageManager()
    
    let swiftDataContainer: ModelContainer
    let backupContainer: ModelContainer
    let coreDataStack: CoreDataStack
    
    private(set) var currentType: StorageType
    
    private(set) var transactionsStorage: TransactionsStorage
    private(set) var accountsStorage: AccountsStorage
    private(set) var categoriesStorage: CategoriesStorage
    private(set) var backupStorage: BackupStorage
    
    private init() {
        do {
            let schema = Schema([
                TransactionEntity.self,
                AccountEntity.self,
                CategoryEntity.self
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            self.swiftDataContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
        
        do {
            let backupSchema = Schema([
                BackupTransactionAction.self,
                BackupAccountAction.self
            ])
            let backupConfig = ModelConfiguration("BackupStore", isStoredInMemoryOnly: false)
            self.backupContainer = try ModelContainer(for: backupSchema, configurations: [backupConfig])
        } catch {
            fatalError("Не удалось создать BackupContainer: \(error)")
        }
        
        self.coreDataStack = CoreDataStack.shared
        
        let initialType = StorageType.current
        self.currentType = initialType
        
        self.transactionsStorage = Self.makeTransactionsStorage(type: initialType, swiftData: swiftDataContainer, coreData: coreDataStack.context)
        self.accountsStorage = Self.makeAccountsStorage(type: initialType, swiftData: swiftDataContainer, coreData: coreDataStack.context)
        self.categoriesStorage = Self.makeCategoriesStorage(type: initialType, swiftData: swiftDataContainer, coreData: coreDataStack.context)
        self.backupStorage = BackupStorage(container: backupContainer)
        
        Task { await migrateIfNeeded() }
    }
    
    private static func makeTransactionsStorage(type: StorageType, swiftData: ModelContainer, coreData: NSManagedObjectContext) -> TransactionsStorage {
        switch type {
        case .swiftData: return TransactionsSwiftDataStorage(container: swiftData)
        case .coreData: return TransactionsCoreDataStorage(context: coreData)
        }
    }
    
    private static func makeAccountsStorage(type: StorageType, swiftData: ModelContainer, coreData: NSManagedObjectContext) -> AccountsStorage {
        switch type {
        case .swiftData: return AccountsSwiftDataStorage(container: swiftData)
        case .coreData: return AccountsCoreDataStorage(context: coreData)
        }
    }
    
    private static func makeCategoriesStorage(type: StorageType, swiftData: ModelContainer, coreData: NSManagedObjectContext) -> CategoriesStorage {
        switch type {
        case .swiftData: return CategoriesSwiftDataStorage(container: swiftData)
        case .coreData: return CategoriesCoreDataStorage(context: coreData)
        }
    }
    
    func switchStorage(to newType: StorageType) async {
        guard newType != currentType else { return }
        
        let oldTransactions = (try? await transactionsStorage.fetchAll()) ?? []
        let oldAccounts = (try? await accountsStorage.fetchAll()) ?? []
        let oldCategories = (try? await categoriesStorage.fetchAll()) ?? []
        
        if newType == .coreData {
            coreDataStack.clearAll()
        } else {
            try? swiftDataContainer.mainContext.delete(model: TransactionEntity.self)
            try? swiftDataContainer.mainContext.delete(model: AccountEntity.self)
            try? swiftDataContainer.mainContext.delete(model: CategoryEntity.self)
            try? swiftDataContainer.mainContext.save()
        }
        
        transactionsStorage = Self.makeTransactionsStorage(type: newType, swiftData: swiftDataContainer, coreData: coreDataStack.context)
        accountsStorage = Self.makeAccountsStorage(type: newType, swiftData: swiftDataContainer, coreData: coreDataStack.context)
        categoriesStorage = Self.makeCategoriesStorage(type: newType, swiftData: swiftDataContainer, coreData: coreDataStack.context)
        
        for t in oldTransactions { try? await transactionsStorage.create(t) }
        for a in oldAccounts { try? await accountsStorage.create(a) }
        try? await categoriesStorage.save(oldCategories)
        
        if newType == .coreData {
            try? swiftDataContainer.mainContext.delete(model: TransactionEntity.self)
            try? swiftDataContainer.mainContext.delete(model: AccountEntity.self)
            try? swiftDataContainer.mainContext.delete(model: CategoryEntity.self)
            try? swiftDataContainer.mainContext.save()
        } else {
            coreDataStack.clearAll()
        }
        
        currentType = newType
    }
    
    private func migrateIfNeeded() async {
        let settings = UserDefaults.standard
        let lastKnownType = StorageType(rawValue: settings.string(forKey: "last_storage_type") ?? "") ?? .swiftData
        
        if lastKnownType != currentType {
            await switchStorage(to: currentType)
        }
        
        settings.set(currentType.rawValue, forKey: "last_storage_type")
    }
}
