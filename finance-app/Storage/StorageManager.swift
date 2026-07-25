import Foundation
import SwiftData

final class StorageManager {
    static let shared = StorageManager()
    
    let container: ModelContainer
    let transactionsStorage: TransactionsStorage
    let accountsStorage: AccountsStorage
    let categoriesStorage: CategoriesStorage
    let backupStorage: BackupStorage
    
    private init() {
        do {
            let schema = Schema([
                TransactionEntity.self,
                AccountEntity.self,
                CategoryEntity.self,
                BackupTransactionAction.self,
                BackupAccountAction.self
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
        
        self.transactionsStorage = TransactionsSwiftDataStorage(container: container)
        self.accountsStorage = AccountsSwiftDataStorage(container: container)
        self.categoriesStorage = CategoriesSwiftDataStorage(container: container)
        self.backupStorage = BackupStorage(container: container)
    }
}
