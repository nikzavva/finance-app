import Foundation

final class TransactionsService {
    private static var syncTask: Task<Void, Never>?

    private let network = NetworkClient.shared
    private var storage: TransactionsStorage { StorageManager.shared.transactionsStorage }
    private var accountsStorage: AccountsStorage { StorageManager.shared.accountsStorage }
    private var backup: BackupStorage { StorageManager.shared.backupStorage }
    
    func fetchTransactions(from startDate: Date, to endDate: Date) async -> [Transaction] {
        await performSync()
        
        let local = (try? await storage.fetchAll()) ?? []
        let backupTransactions = (try? backup.fetchAllTransactionActions())?
            .filter { $0.actionType != .delete }
            .map { $0.toTransaction() } ?? []
        
        guard NetworkMonitor.shared.isConnected else {
            NetworkMonitor.shared.markOfflineDataUsed()
            return mergeAndFilter(local: local, backup: backupTransactions, from: startDate, to: endDate)
        }
        
        do {
            let accounts = try await network.get(endpoint: "/accounts") as [BankAccountDTO]
            guard !accounts.isEmpty else {
                NetworkMonitor.shared.markDataFresh()
                return mergeAndFilter(local: local, backup: backupTransactions, from: startDate, to: endDate)
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            var serverTransactions: [Transaction] = []
            
            await withTaskGroup(of: [Transaction].self) { group in
                for account in accounts {
                    group.addTask { [self] in
                        do {
                            let queryItems = [
                                URLQueryItem(name: "startDate", value: dateFormatter.string(from: startDate)),
                                URLQueryItem(name: "endDate", value: dateFormatter.string(from: endDate))
                            ]
                            let dtos: [TransactionDTO] = try await self.network.get(
                                endpoint: "/transactions/account/\(account.id)/period",
                                queryItems: queryItems
                            )
                            return dtos.map { $0.toDomain() }
                        } catch {
                            return []
                        }
                    }
                }
                
                for await transactions in group {
                    serverTransactions.append(contentsOf: transactions)
                }
            }
            
            let backupActions = (try? backup.fetchAllTransactionActions()) ?? []
            let serverTransactionIDs = Set(serverTransactions.map(\.id))
            let protectedTransactionIDs = Set(backupActions.map(\.transactionId))

            let staleLocalTransactionIDs: Set<Int> = Set(local.compactMap { transaction in
                guard !isTemporaryTransactionID(transaction.id),
                      !protectedTransactionIDs.contains(transaction.id),
                      transaction.transactionDate >= startDate,
                      transaction.transactionDate < endDate,
                      !serverTransactionIDs.contains(transaction.id) else {
                    return nil
                }
                return transaction.id
            })

            for id in staleLocalTransactionIDs {
                try? await storage.delete(byId: id)
            }

            for transaction in serverTransactions {
                try? await storage.update(transaction)
            }
            
            NetworkMonitor.shared.markDataFresh()
            let reconciledLocal = local.filter { !staleLocalTransactionIDs.contains($0.id) }
            return mergeAndFilter(
                local: reconciledLocal + serverTransactions,
                backup: backupTransactions,
                from: startDate,
                to: endDate
            )
        } catch {
            NetworkMonitor.shared.markOfflineDataUsed()
            return mergeAndFilter(local: local, backup: backupTransactions, from: startDate, to: endDate)
        }
    }
    
    func fetchTransactionsForAccount(id: Int) async -> [Transaction] {
        let local = (try? await storage.fetchAll()) ?? []
        let backupTransactions = (try? backup.fetchAllTransactionActions())?
            .filter { $0.actionType != .delete }
            .map { $0.toTransaction() } ?? []
        
        var merged: [Int: Transaction] = [:]
        for t in local { merged[t.id] = t }
        for t in backupTransactions { merged[t.id] = t }
        
        return Array(merged.values).filter { $0.accountId == id }
    }
    
    func createTransaction(_ transaction: Transaction) async {
        let tempId = Int(Date().timeIntervalSince1970 * 1000)
        let localTransaction = Transaction(
            id: tempId,
            accountId: transaction.accountId,
            categoryId: transaction.categoryId,
            amount: transaction.amount,
            transactionDate: transaction.transactionDate,
            comment: transaction.comment,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            direction: transaction.direction
        )
        
        try? await storage.create(localTransaction)
        await adjustAccountBalance(accountId: transaction.accountId, delta: balanceDelta(for: transaction))
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        NotificationCenter.default.post(name: .accountsDidChange, object: nil)
        
        guard NetworkMonitor.shared.isConnected else {
            try? backup.addTransactionAction(localTransaction, action: .create)
            return
        }
        
        Task {
            let request = TransactionRequestDTO(from: transaction)
            do {
                let dto: TransactionCreatedDTO = try await network.request(
                    endpoint: "/transactions",
                    method: .post,
                    body: request
                )
                let created = dto.toDomain(direction: transaction.direction)
                try? await storage.delete(byId: tempId)
                try? await storage.create(created)
                try? backup.removeTransactionAction(byId: tempId)
                NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
            } catch {
                try? backup.addTransactionAction(localTransaction, action: .create)
            }
        }
    }
    
    func updateTransaction(_ transaction: Transaction) async {
        let oldTransaction = try? await storage.fetch(byIds: [transaction.id]).first
        
        try? await storage.update(transaction)
        
        if let old = oldTransaction {
            await adjustAccountBalance(accountId: old.accountId, delta: -balanceDelta(for: old))
        }
        await adjustAccountBalance(accountId: transaction.accountId, delta: balanceDelta(for: transaction))
        
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        NotificationCenter.default.post(name: .accountsDidChange, object: nil)
        
        guard NetworkMonitor.shared.isConnected else {
            try? backup.addTransactionAction(transaction, action: .update)
            return
        }
        
        Task {
            let request = TransactionRequestDTO(from: transaction)
            do {
                let dto: TransactionCreatedDTO = try await network.request(
                    endpoint: "/transactions/\(transaction.id)",
                    method: .put,
                    body: request
                )
                let updated = dto.toDomain(direction: transaction.direction)
                try? await storage.update(updated)
                try? backup.removeTransactionAction(byId: transaction.id)
                NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
            } catch {
                try? backup.addTransactionAction(transaction, action: .update)
            }
        }
    }
    
    func deleteTransaction(id: Int) async {
        if let local = try? await storage.fetch(byIds: [id]).first {
            try? backup.addTransactionAction(local, action: .delete)
            try? await storage.delete(byId: id)
            await adjustAccountBalance(accountId: local.accountId, delta: -balanceDelta(for: local))
        }
        
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        NotificationCenter.default.post(name: .accountsDidChange, object: nil)
        
        guard NetworkMonitor.shared.isConnected else { return }
        
        Task {
            do {
                try await network.delete(endpoint: "/transactions/\(id)")
                try? backup.removeTransactionAction(byId: id)
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
            let accountsService = BankAccountsService()
            _ = await accountsService.fetchAccounts()
            await syncBackupToBackend()
        }
        
        await Self.syncTask?.value
    }
    
    private func balanceDelta(for transaction: Transaction) -> Decimal {
        transaction.direction == .income ? transaction.amount : -transaction.amount
    }

    private func isTemporaryTransactionID(_ id: Int) -> Bool {
        id > 1_000_000_000
    }
    
    private func adjustAccountBalance(accountId: Int, delta: Decimal) async {
        guard var account = try? await accountsStorage.fetch(byId: accountId) else {
            print("❌ Account \(accountId) not found for balance adjustment")
            return
        }
        print("📊 Adjusting balance for account \(accountId): \(account.balance) + \(delta)")
        account = BankAccount(
            id: account.id,
            userId: account.userId,
            name: account.name,
            emoji: account.emoji,
            balance: account.balance + delta,
            currency: account.currency,
            createdAt: account.createdAt,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        print("📊 New balance: \(account.balance)")
        do {
            try await accountsStorage.update(account)
            print("✅ Balance updated successfully")
        } catch {
            print("❌ Failed to update balance: \(error)")
        }
    }
    
    private func mergeAndFilter(local: [Transaction], backup: [Transaction], from startDate: Date, to endDate: Date) -> [Transaction] {
        var merged: [Int: Transaction] = [:]
        for t in local { merged[t.id] = t }
        for t in backup { merged[t.id] = t }
        
        let result = Array(merged.values)
        return result.filter {
            $0.transactionDate >= startDate && $0.transactionDate < endDate
        }
    }
    
    private func syncBackupToBackend() async {
        guard NetworkMonitor.shared.isConnected else { return }
        guard let actions = try? backup.fetchAllTransactionActions() else { return }
        guard !actions.isEmpty else { return }
        
        for action in actions {
            let transaction = action.toTransaction()
            
            if isTemporaryTransactionID(transaction.id) {
                switch action.actionType {
                case .create:
                    let request = TransactionRequestDTO(from: transaction)
                    do {
                        let dto: TransactionCreatedDTO = try await network.request(
                            endpoint: "/transactions",
                            method: .post,
                            body: request
                        )
                        let created = dto.toDomain(direction: transaction.direction)
                        try? await storage.delete(byId: transaction.id)
                        try? await storage.create(created)
                        try? backup.removeTransactionAction(byId: transaction.id)
                    } catch {
                        print("❌ Failed to sync create transaction: \(error)")
                    }
                    
                case .update:
                    try? backup.removeTransactionAction(byId: transaction.id)
                    
                case .delete:
                    try? backup.removeTransactionAction(byId: transaction.id)
                }
                continue
            }
            
            switch action.actionType {
            case .create:
                let request = TransactionRequestDTO(from: transaction)
                do {
                    let dto: TransactionCreatedDTO = try await network.request(
                        endpoint: "/transactions",
                        method: .post,
                        body: request
                    )
                    let created = dto.toDomain(direction: transaction.direction)
                    try? await storage.delete(byId: transaction.id)
                    try? await storage.create(created)
                    try? backup.removeTransactionAction(byId: transaction.id)
                } catch {
                    print("❌ Failed to sync create transaction: \(error)")
                }
                
            case .update:
                let request = TransactionRequestDTO(from: transaction)
                do {
                    let dto: TransactionCreatedDTO = try await network.request(
                        endpoint: "/transactions/\(transaction.id)",
                        method: .put,
                        body: request
                    )
                    let updated = dto.toDomain(direction: transaction.direction)
                    try? await storage.update(updated)
                    try? backup.removeTransactionAction(byId: transaction.id)
                } catch {
                    print("❌ Failed to sync update transaction: \(error)")
                }
                
            case .delete:
                do {
                    try await network.delete(endpoint: "/transactions/\(transaction.id)")
                    try? await storage.delete(byId: transaction.id)
                    try? backup.removeTransactionAction(byId: transaction.id)
                } catch {
                    print("❌ Failed to sync delete transaction: \(error)")
                }
            }
        }
        
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
    }
}
