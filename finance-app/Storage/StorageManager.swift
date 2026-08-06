import Foundation
import SwiftData
import CoreData

enum StorageMigrationError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        "Не удалось проверить целостность перенесённых данных"
    }
}

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
    
    func switchStorage(to newType: StorageType) async throws {
        try await DataMutationCoordinator.shared.withLock {
            guard newType != currentType else { return }
            try await migrateStorage(from: currentType, to: newType)
            currentType = newType
            UserDefaults.standard.set(newType.rawValue, forKey: "last_storage_type")
        }
    }
    
    func migrateIfNeeded() async throws {
        let settings = UserDefaults.standard
        let lastKnownType = StorageType(rawValue: settings.string(forKey: "last_storage_type") ?? "") ?? .swiftData

        if lastKnownType != currentType {
            try await DataMutationCoordinator.shared.withLock {
                try await migrateStorage(from: lastKnownType, to: currentType)
            }
        }

        settings.set(currentType.rawValue, forKey: "last_storage_type")
    }

    private func migrateStorage(from sourceType: StorageType, to destinationType: StorageType) async throws {
        guard sourceType != destinationType else { return }

        let sourceTransactionsStorage = Self.makeTransactionsStorage(type: sourceType, swiftData: swiftDataContainer, coreData: coreDataStack.context)
        let sourceAccountsStorage = Self.makeAccountsStorage(type: sourceType, swiftData: swiftDataContainer, coreData: coreDataStack.context)
        let sourceCategoriesStorage = Self.makeCategoriesStorage(type: sourceType, swiftData: swiftDataContainer, coreData: coreDataStack.context)

        let transactions = try await sourceTransactionsStorage.fetchAll()
        let accounts = try await sourceAccountsStorage.fetchAll()
        let categories = try await sourceCategoriesStorage.fetchAll()

        let destinationTransactionsStorage = Self.makeTransactionsStorage(type: destinationType, swiftData: swiftDataContainer, coreData: coreDataStack.context)
        let destinationAccountsStorage = Self.makeAccountsStorage(type: destinationType, swiftData: swiftDataContainer, coreData: coreDataStack.context)
        let destinationCategoriesStorage = Self.makeCategoriesStorage(type: destinationType, swiftData: swiftDataContainer, coreData: coreDataStack.context)

        try await destinationTransactionsStorage.deleteAll()
        try await destinationAccountsStorage.deleteAll()
        try await destinationCategoriesStorage.save([])

        for transaction in transactions {
            try await destinationTransactionsStorage.create(transaction)
        }
        for account in accounts {
            try await destinationAccountsStorage.create(account)
        }
        try await destinationCategoriesStorage.save(categories)

        let migratedTransactions = try await destinationTransactionsStorage.fetchAll()
        let migratedAccounts = try await destinationAccountsStorage.fetchAll()
        let migratedCategories = try await destinationCategoriesStorage.fetchAll()

        guard Set(migratedTransactions.map(\.id)) == Set(transactions.map(\.id)),
              Set(migratedAccounts.map(\.id)) == Set(accounts.map(\.id)),
              Set(migratedCategories.map(\.id)) == Set(categories.map(\.id)) else {
            throw StorageMigrationError.verificationFailed
        }

        try await sourceTransactionsStorage.deleteAll()
        try await sourceAccountsStorage.deleteAll()
        try await sourceCategoriesStorage.save([])

        transactionsStorage = destinationTransactionsStorage
        accountsStorage = destinationAccountsStorage
        categoriesStorage = destinationCategoriesStorage
    }
}
