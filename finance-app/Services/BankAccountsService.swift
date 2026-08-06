import Foundation

enum AccountDeletionResult: Equatable {
    case deleted
    case hasTransactions
    case failed
}

final class BankAccountsService {
    private static var syncTask: Task<Void, Never>?
    private static var syncRequested = false

    private let network = NetworkClient.shared
    private var storage: AccountsStorage { StorageManager.shared.accountsStorage }
    private var backup: BackupStorage { StorageManager.shared.backupStorage }
    
    func fetchAccounts() async -> [BankAccount] {
        await performSync()
        
        guard NetworkMonitor.shared.isConnected else {
            NetworkMonitor.shared.markOfflineDataUsed()
            return await fetchAccountsOffline()
        }

        let pendingAtRequestStart = try? await DataMutationCoordinator.shared.withLock {
            let accountActions = try backup.fetchAllAccountActions()
            let transactionActions = try backup.fetchAllTransactionActions()
            return (
                Set(accountActions.map(\.accountId)),
                !accountActions.isEmpty,
                !transactionActions.isEmpty
            )
        }
        let protectedAccountIDsAtRequestStart = pendingAtRequestStart?.0 ?? []
        let hadPendingAccountActionsAtRequestStart = pendingAtRequestStart?.1 ?? false
        let hadPendingTransactionActionsAtRequestStart = pendingAtRequestStart?.2 ?? false

        do {
            let dtos: [BankAccountDTO] = try await network.get(endpoint: "/accounts")
            let serverAccounts = dtos.map { $0.toDomain() }

            try await DataMutationCoordinator.shared.withLock {
                let backupActions = try backup.fetchAllAccountActions()
                let transactionActions = try backup.fetchAllTransactionActions()
                let localAccounts = try await storage.fetchAll()
                let localByID = Dictionary(uniqueKeysWithValues: localAccounts.map { ($0.id, $0) })
                let pendingAccountIDs = Set(backupActions.map(\.accountId))
                    .union(protectedAccountIDsAtRequestStart)
                let shouldPreserveBalances = !transactionActions.isEmpty || hadPendingTransactionActionsAtRequestStart

                for serverAccount in serverAccounts where !pendingAccountIDs.contains(serverAccount.id) {
                    let account: BankAccount
                    if shouldPreserveBalances, let localAccount = localByID[serverAccount.id] {
                        account = BankAccount(
                            id: serverAccount.id,
                            userId: serverAccount.userId,
                            name: serverAccount.name,
                            emoji: serverAccount.emoji,
                            balance: localAccount.balance,
                            currency: serverAccount.currency,
                            createdAt: serverAccount.createdAt,
                            updatedAt: serverAccount.updatedAt
                        )
                    } else {
                        account = serverAccount
                    }
                    try await storage.update(account)
                }

                if backupActions.isEmpty,
                   transactionActions.isEmpty,
                   !hadPendingAccountActionsAtRequestStart,
                   !hadPendingTransactionActionsAtRequestStart {
                    let serverIDs = Set(serverAccounts.map(\.id))
                    for localAccount in localAccounts
                    where localAccount.id <= 1_000_000_000 && !serverIDs.contains(localAccount.id) {
                        try await storage.delete(byId: localAccount.id)
                    }
                }
            }
            
            let hasPendingActions = (try? await DataMutationCoordinator.shared.withLock {
                let accountActions = try backup.fetchAllAccountActions()
                let transactionActions = try backup.fetchAllTransactionActions()
                return !accountActions.isEmpty || !transactionActions.isEmpty
            }) ?? true
            if hasPendingActions {
                NetworkMonitor.shared.markOfflineDataUsed()
            } else {
                NetworkMonitor.shared.markDataFresh()
            }
            return await fetchAccountsOffline()
        } catch {
            NetworkMonitor.shared.markOfflineDataUsed()
            return await fetchAccountsOffline()
        }
    }
    
    func createAccount(_ account: BankAccount) async -> BankAccount {
        let tempId = await TemporaryIDGenerator.shared.next()
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

        let resource = DataResource.account(tempId)
        guard await InFlightDataRegistry.shared.begin(resource) else { return localAccount }

        do {
            try await DataMutationCoordinator.shared.withLock {
                try await storage.create(localAccount)
                do {
                    try backup.addAccountAction(localAccount, action: .create)
                } catch {
                    try? await storage.delete(byId: localAccount.id)
                    throw error
                }
            }
        } catch {
            await InFlightDataRegistry.shared.end(resource)
            return localAccount
        }

        NotificationCenter.default.post(name: .accountsDidChange, object: nil)
        
        guard NetworkMonitor.shared.isConnected else {
            await InFlightDataRegistry.shared.end(resource)
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
                try await DataMutationCoordinator.shared.withLock {
                    let localBalance = try await storage.fetch(byId: tempId)?.balance ?? created.balance
                    let localCreated = self.account(created, withBalance: localBalance)
                    try await updateTransactionsAccountId(from: tempId, to: created.id)
                    try await storage.delete(byId: tempId)
                    try await storage.update(localCreated)
                    try backup.removeAccountAction(byId: tempId)
                }
                NotificationCenter.default.post(name: .accountsDidChange, object: nil)
                NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
            } catch {
            }
            await InFlightDataRegistry.shared.end(resource)
        }
        
        return localAccount
    }
    
    func updateAccount(_ account: BankAccount) async -> BankAccount {
        let resource = DataResource.account(account.id)
        await InFlightDataRegistry.shared.acquire(resource)

        do {
            try await DataMutationCoordinator.shared.withLock {
                guard let previousAccount = try await storage.fetch(byId: account.id) else {
                    throw NetworkError.noData
                }
                try await storage.update(account)
                do {
                    try backup.addAccountAction(account, action: .update)
                } catch {
                    try? await storage.update(previousAccount)
                    throw error
                }
            }
        } catch {
            await InFlightDataRegistry.shared.end(resource)
            return account
        }

        NotificationCenter.default.post(name: .accountsDidChange, object: nil)
        
        guard NetworkMonitor.shared.isConnected, account.id <= 1_000_000_000 else {
            await InFlightDataRegistry.shared.end(resource)
            if NetworkMonitor.shared.isConnected {
                Task { await performSync() }
            }
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
                try await reconcileSuccessfulAccountUpdate(updated, id: account.id)
                NotificationCenter.default.post(name: .accountsDidChange, object: nil)
            } catch {
            }
            await InFlightDataRegistry.shared.end(resource)
        }
        
        return account
    }
    
    func deleteAccount(id: Int) async -> AccountDeletionResult {
        let resource = DataResource.account(id)
        await InFlightDataRegistry.shared.acquire(resource)

        let localResult = await DataMutationCoordinator.shared.withLock {
            await deleteLocalAccount(id: id)
        }

        guard localResult == .deleted else {
            await InFlightDataRegistry.shared.end(resource)
            return localResult
        }

        NotificationCenter.default.post(name: .accountsDidChange, object: nil)
        
        guard NetworkMonitor.shared.isConnected, id <= 1_000_000_000 else {
            await InFlightDataRegistry.shared.end(resource)
            return .deleted
        }
        
        Task {
            var didDeleteRemotely = false
            do {
                try await network.delete(endpoint: "/accounts/\(id)", reportsActivity: false)
                try await DataMutationCoordinator.shared.withLock {
                    try backup.removeAccountAction(byId: id)
                }
                didDeleteRemotely = true
            } catch {
                if isPermanentSyncError(error) {
                    _ = await restoreRejectedAccountDeletion(id: id)
                }
            }
            await InFlightDataRegistry.shared.end(resource)
            if didDeleteRemotely {
                NotificationCenter.default.post(name: .accountsDidChange, object: nil)
            }
        }

        return .deleted
    }

    private func deleteLocalAccount(id: Int) async -> AccountDeletionResult {
        do {
            let transactions = try await StorageManager.shared.transactionsStorage.fetchAll()
            let pendingTransactions = try backup.fetchAllTransactionActions()
                .filter { $0.actionType != .delete }
                .map { $0.toTransaction() }

            guard !transactions.contains(where: { $0.accountId == id }),
                  !pendingTransactions.contains(where: { $0.accountId == id }) else {
                return .hasTransactions
            }

            guard let account = try await storage.fetch(byId: id) else { return .deleted }
            do {
                try await storage.delete(byId: id)
                do {
                    try backup.addAccountAction(account, action: .delete)
                    return .deleted
                } catch {
                    try? await storage.update(account)
                    return .failed
                }
            } catch {
                return .failed
            }
        } catch {
            return .failed
        }
    }
    
    private func performSync() async {
        if let task = Self.syncTask {
            Self.syncRequested = true
            await task.value
            return
        }
        
        Self.syncTask = Task {
            defer { Self.syncTask = nil }
            repeat {
                Self.syncRequested = false
                await syncBackupToBackend()
            } while Self.syncRequested
        }
        
        await Self.syncTask?.value
    }
    
    private func fetchAccountsOffline() async -> [BankAccount] {
        let snapshot = try? await DataMutationCoordinator.shared.withLock {
            let local = try await storage.fetchAll()
            let actions = try backup.fetchAllAccountActions()
            return (local, actions)
        }
        let local = snapshot?.0 ?? []
        let backupActions = snapshot?.1 ?? []
        let pendingDeletionIDs = Set(
            backupActions
                .filter { $0.actionType == .delete }
                .map(\.accountId)
        )
        var merged: [Int: BankAccount] = [:]
        for a in local where !pendingDeletionIDs.contains(a.id) { merged[a.id] = a }
        for action in backupActions where action.actionType != .delete {
            let account = action.toAccount()
            if action.actionType == .update || merged[account.id] == nil {
                merged[account.id] = account
            }
        }
        return Array(merged.values)
    }
    
    private func syncBackupToBackend() async {
        guard NetworkMonitor.shared.isConnected else { return }
        guard let snapshot = try? await DataMutationCoordinator.shared.withLock({
            let accountActions = try backup.fetchAllAccountActions()
            let transactionActions = try backup.fetchAllTransactionActions()
            return (accountActions, transactionActions)
        }) else { return }
        let actions = snapshot.0
        let hasPendingTransactions = !snapshot.1.isEmpty
        guard !actions.isEmpty else { return }

        var didSync = false
        
        for action in actions {
            let account = action.toAccount()
            if hasPendingTransactions, action.actionType != .create {
                continue
            }
            let resource = DataResource.account(account.id)
            guard await InFlightDataRegistry.shared.begin(resource) else { continue }

            let synced: Bool
            switch action.actionType {
            case .create:
                synced = await syncPendingCreate(account)
            case .update:
                synced = await syncPendingUpdate(account)
            case .delete:
                synced = await syncPendingDelete(account)
            }

            await InFlightDataRegistry.shared.end(resource)
            didSync = synced || didSync
        }

        if didSync {
            NotificationCenter.default.post(name: .accountsDidChange, object: nil)
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        }
    }

    private func syncPendingCreate(_ account: BankAccount) async -> Bool {
        let accountForCreation = (try? await DataMutationCoordinator.shared.withLock {
            let localAccount = try await storage.fetch(byId: account.id) ?? account
            let transactionActions = try backup.fetchAllTransactionActions()
            let pendingDelta = transactionActions
                .filter { $0.actionType == .create && $0.accountId == account.id }
                .map { $0.toTransaction() }
                .reduce(Decimal.zero) { result, transaction in
                    result + (transaction.direction == .income ? transaction.amount : -transaction.amount)
                }
            return self.account(localAccount, withBalance: localAccount.balance - pendingDelta)
        }) ?? account
        let request = CreateAccountRequestDTO(from: accountForCreation)
        do {
            let dto: BankAccountDTO = try await network.request(
                endpoint: "/accounts",
                method: .post,
                body: request,
                reportsActivity: false,
                presentsError: false
            )
            let created = dto.toDomain()
            try await DataMutationCoordinator.shared.withLock {
                let localBalance = try await storage.fetch(byId: account.id)?.balance ?? created.balance
                let localCreated = self.account(created, withBalance: localBalance)
                try await updateTransactionsAccountId(from: account.id, to: created.id)
                try await storage.delete(byId: account.id)
                try await storage.update(localCreated)
                try backup.removeAccountAction(byId: account.id)
            }
            return true
        } catch {
            return false
        }
    }

    private func syncPendingUpdate(_ account: BankAccount) async -> Bool {
        if account.id > 1_000_000_000 {
            do {
                try await DataMutationCoordinator.shared.withLock {
                    try backup.removeAccountAction(byId: account.id)
                }
                return true
            } catch {
                return false
            }
        }

        let currentAccount = (try? await DataMutationCoordinator.shared.withLock {
            try await storage.fetch(byId: account.id)
        }) ?? account
        let request = UpdateAccountRequestDTO(from: currentAccount)
        do {
            let dto: BankAccountDTO = try await network.request(
                endpoint: "/accounts/\(account.id)",
                method: .put,
                body: request,
                reportsActivity: false,
                presentsError: false
            )
            let updated = dto.toDomain()
            try await reconcileSuccessfulAccountUpdate(updated, id: account.id)
            return true
        } catch {
            return false
        }
    }

    private func syncPendingDelete(_ account: BankAccount) async -> Bool {
        if account.id > 1_000_000_000 {
            do {
                try await DataMutationCoordinator.shared.withLock {
                    try backup.removeAccountAction(byId: account.id)
                }
                return true
            } catch {
                return false
            }
        }

        do {
            try await network.delete(
                endpoint: "/accounts/\(account.id)",
                reportsActivity: false,
                presentsError: false
            )
            try await DataMutationCoordinator.shared.withLock {
                try await storage.delete(byId: account.id)
                try backup.removeAccountAction(byId: account.id)
            }
            return true
        } catch {
            if isPermanentSyncError(error) {
                return await restoreRejectedAccountDeletion(id: account.id)
            }
            return false
        }
    }

    private func restoreRejectedAccountDeletion(id: Int) async -> Bool {
        do {
            try await DataMutationCoordinator.shared.withLock {
                let actions = try backup.fetchAllAccountActions()
                guard let action = actions.first(where: {
                    $0.accountId == id && $0.actionType == .delete
                }) else {
                    throw NetworkError.noData
                }
                try await storage.update(action.toAccount())
                try backup.removeAccountAction(byId: id)
            }
            NotificationCenter.default.post(name: .accountsDidChange, object: nil)
            return true
        } catch {
            return false
        }
    }

    private func reconcileSuccessfulAccountUpdate(_ updated: BankAccount, id: Int) async throws {
        try await DataMutationCoordinator.shared.withLock {
            let localAccount = try await storage.fetch(byId: id) ?? updated
            let reconciledAccount = account(updated, withBalance: localAccount.balance)
            let transactionActions = try backup.fetchAllTransactionActions()
            try await storage.update(reconciledAccount)

            if localAccount.balance == updated.balance && transactionActions.isEmpty {
                try backup.removeAccountAction(byId: id)
            } else {
                try backup.addAccountAction(reconciledAccount, action: .update)
            }
        }
    }

    private func isPermanentSyncError(_ error: Error) -> Bool {
        guard let networkError = error as? NetworkError else { return false }

        switch networkError {
        case .notFound, .conflict:
            return true
        case .httpError(let statusCode, _):
            return (400..<500).contains(statusCode) && statusCode != 408 && statusCode != 429
        case .invalidURL, .serializationError, .deserializationError, .noData, .unauthorized, .networkUnavailable:
            return false
        }
    }

    private func updateTransactionsAccountId(from oldId: Int, to newId: Int) async throws {
        let transactions = try await StorageManager.shared.transactionsStorage.fetchAll()
        let backupActions = try backup.fetchAllTransactionActions()

        for transaction in transactions where transaction.accountId == oldId {
            let updatedTransaction = transaction.replacingAccountId(with: newId)
            try await StorageManager.shared.transactionsStorage.update(updatedTransaction)
        }

        for backupAction in backupActions where backupAction.accountId == oldId {
            let updatedBackedUpTransaction = backupAction.toTransaction().replacingAccountId(with: newId)
            try backup.addTransactionAction(
                updatedBackedUpTransaction,
                action: backupAction.actionType
            )
        }
    }

    private func account(_ account: BankAccount, withBalance balance: Decimal) -> BankAccount {
        BankAccount(
            id: account.id,
            userId: account.userId,
            name: account.name,
            emoji: account.emoji,
            balance: balance,
            currency: account.currency,
            createdAt: account.createdAt,
            updatedAt: account.updatedAt
        )
    }
}

private extension Transaction {
    func replacingAccountId(with accountId: Int) -> Transaction {
        Transaction(
            id: id,
            accountId: accountId,
            categoryId: categoryId,
            amount: amount,
            transactionDate: transactionDate,
            comment: comment,
            createdAt: createdAt,
            updatedAt: updatedAt,
            direction: direction
        )
    }
}
