import Foundation

final class BankAccountsService {
    private static var syncTask: Task<Void, Never>?

    private let network = NetworkClient.shared
    private var storage: AccountsStorage { StorageManager.shared.accountsStorage }
    private var backup: BackupStorage { StorageManager.shared.backupStorage }
    
    func fetchAccounts() async -> [BankAccount] {
        await performSync()
        
        guard NetworkMonitor.shared.isConnected else {
            NetworkMonitor.shared.markOfflineDataUsed()
            return await fetchAccountsOffline()
        }
        
        do {
            let dtos: [BankAccountDTO] = try await network.get(endpoint: "/accounts")
            let serverAccounts = dtos.map { $0.toDomain() }
            
            let backupActions = (try? backup.fetchAllAccountActions()) ?? []
            if backupActions.isEmpty {
                try? await storage.deleteAll()
                for account in serverAccounts {
                    try? await storage.create(account)
                }
            } else {
                for account in serverAccounts {
                    try? await storage.update(account)
                }
            }
            
            NetworkMonitor.shared.markDataFresh()
            return await fetchAccountsOffline()
        } catch {
            NetworkMonitor.shared.markOfflineDataUsed()
            return await fetchAccountsOffline()
        }
    }
    
    func createAccount(_ account: BankAccount) async -> BankAccount {
        let tempId = Int(Date().timeIntervalSince1970 * 1000)
        let localAccount = BankAccount(
            id: tempId,
            userId: account.userId,
            name: account.name,
            emoji: account.emoji,
            balance: account.balance,
            currency: account.currency,
            createdAt: account.createdAt,
            updatedAt: account.updatedAt
        )
        
        try? await storage.create(localAccount)
        NotificationCenter.default.post(name: .accountsDidChange, object: nil)
        
        guard NetworkMonitor.shared.isConnected else {
            let originalBalance = account.balance
            let backupAccount = BankAccount(
                id: tempId,
                userId: account.userId,
                name: account.name,
                emoji: account.emoji,
                balance: originalBalance,
                currency: account.currency,
                createdAt: account.createdAt,
                updatedAt: account.updatedAt
            )
            try? backup.addAccountAction(backupAccount, action: .create)
            return localAccount
        }
        
        Task {
            let request = CreateAccountRequestDTO(from: account)
            do {
                let dto: BankAccountDTO = try await network.request(
                    endpoint: "/accounts",
                    method: .post,
                    body: request
                )
                let created = dto.toDomain()
                try? await storage.delete(byId: tempId)
                try? await storage.create(created)
                try? backup.removeAccountAction(byId: tempId)
                NotificationCenter.default.post(name: .accountsDidChange, object: nil)
            } catch {
                try? backup.addAccountAction(account, action: .create)
            }
        }
        
        return localAccount
    }
    
    func updateAccount(_ account: BankAccount) async -> BankAccount {
        try? await storage.update(account)
        NotificationCenter.default.post(name: .accountsDidChange, object: nil)
        
        guard NetworkMonitor.shared.isConnected else {
            try? backup.addAccountAction(account, action: .update)
            return account
        }
        
        Task {
            let request = UpdateAccountRequestDTO(from: account)
            do {
                let dto: BankAccountDTO = try await network.request(
                    endpoint: "/accounts/\(account.id)",
                    method: .put,
                    body: request
                )
                let updated = dto.toDomain()
                try? await storage.update(updated)
                try? backup.removeAccountAction(byId: account.id)
                NotificationCenter.default.post(name: .accountsDidChange, object: nil)
            } catch {
                try? backup.addAccountAction(account, action: .update)
            }
        }
        
        return account
    }
    
    func deleteAccount(id: Int) async {
        if let local = try? await storage.fetch(byId: id) {
            try? backup.addAccountAction(local, action: .delete)
        }
        try? await storage.delete(byId: id)
        NotificationCenter.default.post(name: .accountsDidChange, object: nil)
        
        guard NetworkMonitor.shared.isConnected else { return }
        
        Task {
            do {
                try await network.delete(endpoint: "/accounts/\(id)")
                try? backup.removeAccountAction(byId: id)
            } catch {
            }
        }
    }
    
    private func performSync() async {
        if let task = Self.syncTask {
            await task.value
            return
        }
        
        Self.syncTask = Task {
            defer { Self.syncTask = nil }
            await syncBackupToBackend()
        }
        
        await Self.syncTask?.value
    }
    
    private func fetchAccountsOffline() async -> [BankAccount] {
        let local = (try? await storage.fetchAll()) ?? []
        let backupAccounts = (try? backup.fetchAllAccountActions())?
            .filter { $0.actionType != .delete }
            .map { $0.toAccount() } ?? []
        
        var merged: [Int: BankAccount] = [:]
        for a in local { merged[a.id] = a }
        for a in backupAccounts {
            if merged[a.id] == nil {
                merged[a.id] = a
            }
        }
        return Array(merged.values)
    }
    
    private func syncBackupToBackend() async {
        guard NetworkMonitor.shared.isConnected else { return }
        guard let actions = try? backup.fetchAllAccountActions() else { return }
        guard !actions.isEmpty else { return }

        var didSync = false
        
        for action in actions {
            let account = action.toAccount()
            
            switch action.actionType {
            case .create:
                let request = CreateAccountRequestDTO(from: account)
                do {
                    let dto: BankAccountDTO = try await network.request(
                        endpoint: "/accounts",
                        method: .post,
                        body: request
                    )
                    let created = dto.toDomain()
                    let tempId = account.id
                    let serverId = created.id
                    
                    try? await storage.delete(byId: tempId)
                    try? await storage.create(created)
                    try? backup.removeAccountAction(byId: tempId)
                    
                    await updateTransactionsAccountId(from: tempId, to: serverId)
                    didSync = true
                    
                } catch {
                    print("❌ Failed to sync create account: \(error)")
                }
            case .update:
                if account.id > 1000000000 {
                    try? backup.removeAccountAction(byId: account.id)
                    continue
                }
                let request = UpdateAccountRequestDTO(from: account)
                do {
                    let dto: BankAccountDTO = try await network.request(
                        endpoint: "/accounts/\(account.id)",
                        method: .put,
                        body: request
                    )
                    let updated = dto.toDomain()
                    try? await storage.update(updated)
                    try? backup.removeAccountAction(byId: account.id)
                    didSync = true
                } catch {
                    print("❌ Failed to sync update account: \(error)")
                }
                
            case .delete:
                if account.id > 1000000000 {
                    try? backup.removeAccountAction(byId: account.id)
                    continue
                }
                do {
                    try await network.delete(endpoint: "/accounts/\(account.id)")
                    try? await storage.delete(byId: account.id)
                    try? backup.removeAccountAction(byId: account.id)
                    didSync = true
                } catch {
                    print("❌ Failed to sync delete account: \(error)")
                }
            }
        }

        if didSync {
            NotificationCenter.default.post(name: .accountsDidChange, object: nil)
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        }
    }
    
    private func updateTransactionsAccountId(from oldId: Int, to newId: Int) async {
        guard let transactions = try? await StorageManager.shared.transactionsStorage.fetchAll() else { return }
        
        for transaction in transactions {
            if transaction.accountId == oldId {
                let updatedTransaction = Transaction(
                    id: transaction.id,
                    accountId: newId,
                    categoryId: transaction.categoryId,
                    amount: transaction.amount,
                    transactionDate: transaction.transactionDate,
                    comment: transaction.comment,
                    createdAt: transaction.createdAt,
                    updatedAt: transaction.updatedAt,
                    direction: transaction.direction
                )
                try? await StorageManager.shared.transactionsStorage.update(updatedTransaction)
                
                if let backupActions = try? backup.fetchAllTransactionActions() {
                    for backupAction in backupActions {
                        let backedUpTx = backupAction.toTransaction()
                        if backedUpTx.id == transaction.id {
                            let updatedBackedUpTx = Transaction(
                                id: backedUpTx.id,
                                accountId: newId,
                                categoryId: backedUpTx.categoryId,
                                amount: backedUpTx.amount,
                                transactionDate: backedUpTx.transactionDate,
                                comment: backedUpTx.comment,
                                createdAt: backedUpTx.createdAt,
                                updatedAt: backedUpTx.updatedAt,
                                direction: backedUpTx.direction
                            )
                            try? backup.removeTransactionAction(byId: backedUpTx.id)
                            try? backup.addTransactionAction(updatedBackedUpTx, action: backupAction.actionType)
                        }
                    }
                }
            }
        }
    }
}
