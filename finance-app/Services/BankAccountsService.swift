import Foundation

final class BankAccountsService {
    private let network = NetworkClient.shared
    private let storage: AccountsStorage
    private let backup: BackupStorage
    
    init() {
        self.storage = StorageManager.shared.accountsStorage
        self.backup = StorageManager.shared.backupStorage
    }
    
    func fetchAccounts() async -> [BankAccount] {
        await syncBackupToBackend()
        
        guard NetworkMonitor.shared.isConnected else {
            return await fetchAccountsOffline()
        }
        
        do {
            let dtos: [BankAccountDTO] = try await network.get(endpoint: "/accounts")
            let accounts = dtos.map { $0.toDomain() }
            
            try? await storage.deleteAll()
            for account in accounts {
                try? await storage.create(account)
            }
            
            return accounts
        } catch {
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
            try? backup.addAccountAction(localAccount, action: .create)
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
                try? backup.addAccountAction(localAccount, action: .create)
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
    
    private func fetchAccountsOffline() async -> [BankAccount] {
        let local = (try? await storage.fetchAll()) ?? []
        let backupAccounts = (try? backup.fetchAllAccountActions())?
            .filter { $0.actionType != .delete }
            .map { $0.toAccount() } ?? []
        
        var merged: [Int: BankAccount] = [:]
        for a in local { merged[a.id] = a }
        for a in backupAccounts { merged[a.id] = a }
        return Array(merged.values)
    }
    
    private func syncBackupToBackend() async {
        guard NetworkMonitor.shared.isConnected else { return }
        guard let actions = try? backup.fetchAllAccountActions() else { return }
        guard !actions.isEmpty else { return }
        
        for action in actions {
            let account = action.toAccount()
            
            do {
                switch action.actionType {
                case .create:
                    let request = CreateAccountRequestDTO(from: account)
                    let dto: BankAccountDTO = try await network.request(
                        endpoint: "/accounts",
                        method: .post,
                        body: request
                    )
                    let created = dto.toDomain()
                    try? await storage.delete(byId: account.id)
                    try? await storage.create(created)
                    try? backup.removeAccountAction(byId: account.id)
                    
                case .update:
                    let request = UpdateAccountRequestDTO(from: account)
                    let dto: BankAccountDTO = try await network.request(
                        endpoint: "/accounts/\(account.id)",
                        method: .put,
                        body: request
                    )
                    let updated = dto.toDomain()
                    try? await storage.update(updated)
                    try? backup.removeAccountAction(byId: account.id)
                    
                case .delete:
                    try await network.delete(endpoint: "/accounts/\(account.id)")
                    try? await storage.delete(byId: account.id)
                    try? backup.removeAccountAction(byId: account.id)
                }
            } catch {
                break
            }
        }
        
        NotificationCenter.default.post(name: .accountsDidChange, object: nil)
    }
}
