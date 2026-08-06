import Foundation

enum TransactionDeletionResult: Equatable {
    case deleted
    case insufficientFunds
    case failed
}

enum TransactionCreationResult: Equatable {
    case created
    case insufficientFunds
    case accountNotFound
    case failed
}

enum TransactionUpdateResult: Equatable {
    case updated
    case insufficientFunds
    case failed
}

struct TransactionPeriodQuery: Equatable {
    let startDate: String
    let endDate: String

    init(from startDate: Date, to endDate: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        let lastIncludedDate = endDate > startDate
            ? endDate.addingTimeInterval(-1)
            : startDate
        let nextUTCDate = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: lastIncludedDate)
        ) ?? endDate

        self.startDate = formatter.string(from: startDate)
        self.endDate = formatter.string(from: nextUTCDate)
    }
}

enum TransactionBalanceValidator {
    static func projectedBalances(
        replacing current: Transaction,
        with updated: Transaction,
        accountBalances: [Int: Decimal]
    ) -> [Int: Decimal]? {
        guard let currentBalance = accountBalances[current.accountId] else { return nil }

        if current.accountId == updated.accountId {
            return [
                current.accountId: currentBalance - balanceDelta(for: current) + balanceDelta(for: updated)
            ]
        }

        guard let updatedBalance = accountBalances[updated.accountId] else { return nil }
        return [
            current.accountId: currentBalance - balanceDelta(for: current),
            updated.accountId: updatedBalance + balanceDelta(for: updated)
        ]
    }

    static func hasSufficientFunds(
        replacing current: Transaction,
        with updated: Transaction,
        accountBalances: [Int: Decimal]
    ) -> Bool {
        guard let projected = projectedBalances(
            replacing: current,
            with: updated,
            accountBalances: accountBalances
        ) else {
            return false
        }
        return projected.values.allSatisfy { $0 >= 0 }
    }

    private static func balanceDelta(for transaction: Transaction) -> Decimal {
        transaction.direction == .income ? transaction.amount : -transaction.amount
    }
}

final class TransactionsService {
    private static var syncTask: Task<Void, Never>?
    private static var syncRequested = false

    private let network = NetworkClient.shared
    private let transactionsStorageProvider: () -> TransactionsStorage
    private let accountsStorageProvider: () -> AccountsStorage
    private var storage: TransactionsStorage { transactionsStorageProvider() }
    private var accountsStorage: AccountsStorage { accountsStorageProvider() }
    private var backup: BackupStorage { StorageManager.shared.backupStorage }

    init(
        transactionsStorageProvider: @escaping () -> TransactionsStorage = { StorageManager.shared.transactionsStorage },
        accountsStorageProvider: @escaping () -> AccountsStorage = { StorageManager.shared.accountsStorage }
    ) {
        self.transactionsStorageProvider = transactionsStorageProvider
        self.accountsStorageProvider = accountsStorageProvider
    }
    
    func fetchTransactions(from startDate: Date, to endDate: Date) async -> [Transaction] {
        await performSync()

        guard !Task.isCancelled else { return [] }

        let localSnapshot = try? await DataMutationCoordinator.shared.withLock {
            let transactions = try await storage.fetchAll()
            let actions = try backup.fetchAllTransactionActions()
            return (transactions, actions)
        }
        let local = localSnapshot?.0 ?? []
        let backupActions = localSnapshot?.1 ?? []
        let backupTransactions = backupActions
            .filter { $0.actionType != .delete }
            .map { $0.toTransaction() }
        let pendingDeletionIDs = Set(
            backupActions
                .filter { $0.actionType == .delete }
                .map(\.transactionId)
        )
        
        guard NetworkMonitor.shared.isConnected else {
            NetworkMonitor.shared.markOfflineDataUsed()
            return mergeAndFilter(
                local: local,
                backup: backupTransactions,
                excluding: pendingDeletionIDs,
                from: startDate,
                to: endDate
            )
        }
        
        do {
            let accounts = try await network.get(endpoint: "/accounts") as [BankAccountDTO]
            guard !accounts.isEmpty else {
                NetworkMonitor.shared.markDataFresh()
                return mergeAndFilter(
                    local: local,
                    backup: backupTransactions,
                    excluding: pendingDeletionIDs,
                    from: startDate,
                    to: endDate
                )
            }
            
            let periodQuery = TransactionPeriodQuery(from: startDate, to: endDate)
            var serverTransactions: [Transaction] = []
            var successfullyLoadedAccountIDs = Set<Int>()

            await withTaskGroup(of: (Int, [Transaction]?).self) { group in
                for account in accounts {
                    group.addTask { [self] in
                        do {
                            let queryItems = [
                                URLQueryItem(name: "startDate", value: periodQuery.startDate),
                                URLQueryItem(name: "endDate", value: periodQuery.endDate)
                            ]
                            let dtos: [TransactionDTO] = try await self.network.get(
                                endpoint: "/transactions/account/\(account.id)/period",
                                queryItems: queryItems
                            )
                            return (account.id, dtos.map { $0.toDomain() })
                        } catch {
                            return (account.id, nil)
                        }
                    }
                }
                
                for await (accountID, transactions) in group {
                    guard let transactions else { continue }
                    successfullyLoadedAccountIDs.insert(accountID)
                    serverTransactions.append(contentsOf: transactions)
                }
            }

            guard !Task.isCancelled else {
                return mergeAndFilter(
                    local: local,
                    backup: backupTransactions,
                    excluding: pendingDeletionIDs,
                    from: startDate,
                    to: endDate
                )
            }

            guard !successfullyLoadedAccountIDs.isEmpty else {
                NetworkMonitor.shared.markOfflineDataUsed()
                return mergeAndFilter(
                    local: local,
                    backup: backupTransactions,
                    excluding: pendingDeletionIDs,
                    from: startDate,
                    to: endDate
                )
            }

            let currentBackupActions = (try? await DataMutationCoordinator.shared.withLock {
                try backup.fetchAllTransactionActions()
            }) ?? []
            var effectiveBackupActionsByID: [Int: BackupTransactionAction] = [:]
            for action in backupActions {
                effectiveBackupActionsByID[action.transactionId] = action
            }
            for action in currentBackupActions {
                effectiveBackupActionsByID[action.transactionId] = action
            }
            let effectiveBackupActions = Array(effectiveBackupActionsByID.values)
            let effectiveBackupTransactions = effectiveBackupActions
                .filter { $0.actionType != .delete }
                .map { $0.toTransaction() }
            let effectivePendingDeletionIDs = Set(
                effectiveBackupActions
                    .filter { $0.actionType == .delete }
                    .map(\.transactionId)
            )
            let serverTransactionIDs = Set(serverTransactions.map(\.id))
            let protectedTransactionIDs = Set(effectiveBackupActions.map(\.transactionId))

            let staleLocalTransactionIDs: Set<Int> = Set(local.compactMap { transaction in
                guard !isTemporaryTransactionID(transaction.id),
                      successfullyLoadedAccountIDs.contains(transaction.accountId),
                      !protectedTransactionIDs.contains(transaction.id),
                      transaction.transactionDate >= startDate,
                      transaction.transactionDate < endDate,
                      !serverTransactionIDs.contains(transaction.id) else {
                    return nil
                }
                return transaction.id
            })

            do {
                try await DataMutationCoordinator.shared.withLock {
                    for id in staleLocalTransactionIDs {
                        try await storage.delete(byId: id)
                    }

                    for transaction in serverTransactions where !protectedTransactionIDs.contains(transaction.id) {
                        try await storage.update(transaction)
                    }
                }
            } catch {
                NetworkMonitor.shared.markOfflineDataUsed()
            }

            if successfullyLoadedAccountIDs.count == accounts.count && effectiveBackupActions.isEmpty {
                NetworkMonitor.shared.markDataFresh()
            } else {
                NetworkMonitor.shared.markOfflineDataUsed()
            }
            let reconciledLocal = local.filter { !staleLocalTransactionIDs.contains($0.id) }
            return mergeAndFilter(
                local: reconciledLocal + serverTransactions,
                backup: effectiveBackupTransactions,
                excluding: effectivePendingDeletionIDs,
                from: startDate,
                to: endDate
            )
        } catch {
            NetworkMonitor.shared.markOfflineDataUsed()
            return mergeAndFilter(
                local: local,
                backup: backupTransactions,
                excluding: pendingDeletionIDs,
                from: startDate,
                to: endDate
            )
        }
    }
    
    func fetchTransactionsForAccount(id: Int) async -> [Transaction] {
        let snapshot = try? await DataMutationCoordinator.shared.withLock {
            let local = try await storage.fetchAll()
            let actions = try backup.fetchAllTransactionActions()
            return (local, actions)
        }
        let local = snapshot?.0 ?? []
        let actions = snapshot?.1 ?? []
        let pendingDeletionIDs = Set(
            actions
                .filter { $0.actionType == .delete }
                .map(\.transactionId)
        )
        let backupTransactions = actions
            .filter { $0.actionType != .delete }
            .map { $0.toTransaction() }
        
        var merged: [Int: Transaction] = [:]
        for t in local where !pendingDeletionIDs.contains(t.id) { merged[t.id] = t }
        for t in backupTransactions { merged[t.id] = t }
        
        return Array(merged.values).filter { $0.accountId == id }
    }

    func synchronizePendingChangesIfNeeded() async {
        guard NetworkMonitor.shared.isConnected else { return }
        let hasPendingChanges = (try? await DataMutationCoordinator.shared.withLock {
            let actions = try backup.fetchAllTransactionActions()
            return !actions.isEmpty
        }) ?? true
        guard hasPendingChanges else { return }
        await performSync()
    }
    
    func createTransaction(_ transaction: Transaction) async -> TransactionCreationResult {
        guard transaction.amount > 0 else { return .failed }

        let tempId = await TemporaryIDGenerator.shared.next()
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

        let resource = DataResource.transaction(tempId)
        guard await InFlightDataRegistry.shared.begin(resource) else { return .failed }

        let localResult = await DataMutationCoordinator.shared.withLock {
            await createLocalTransaction(localTransaction)
        }

        guard localResult == .created else {
            await InFlightDataRegistry.shared.end(resource)
            return localResult
        }

        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        NotificationCenter.default.post(name: .accountsDidChange, object: nil)
        
        guard NetworkMonitor.shared.isConnected, !isTemporaryTransactionID(transaction.accountId) else {
            await InFlightDataRegistry.shared.end(resource)
            if NetworkMonitor.shared.isConnected {
                Task { await performSync() }
            }
            return .created
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
                try await DataMutationCoordinator.shared.withLock {
                    try await storage.delete(byId: tempId)
                    try await storage.update(created)
                    try backup.removeTransactionAction(byId: tempId)
                }
                NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
            } catch {
            }
            await InFlightDataRegistry.shared.end(resource)
        }

        return .created
    }
    
    func updateTransaction(_ transaction: Transaction) async -> TransactionUpdateResult {
        guard transaction.amount > 0 else { return .failed }
        let resource = DataResource.transaction(transaction.id)
        await InFlightDataRegistry.shared.acquire(resource)
        let result = await updateTransactionWhileInFlight(transaction)
        await InFlightDataRegistry.shared.end(resource)
        if result == .updated,
           isTemporaryTransactionID(transaction.id),
           NetworkMonitor.shared.isConnected {
            Task { await performSync() }
        }
        return result
    }

    private func updateTransactionWhileInFlight(_ transaction: Transaction) async -> TransactionUpdateResult {
        let localResult = await DataMutationCoordinator.shared.withLock {
            await applyLocalTransactionUpdate(transaction)
        }

        guard localResult == .updated else { return localResult }

        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        NotificationCenter.default.post(name: .accountsDidChange, object: nil)

        guard NetworkMonitor.shared.isConnected,
              !isTemporaryTransactionID(transaction.id) else {
            return .updated
        }

        let request = TransactionRequestDTO(from: transaction)
        do {
            try await network.send(
                endpoint: "/transactions/\(transaction.id)",
                method: .put,
                body: request
            )
            try await DataMutationCoordinator.shared.withLock {
                try backup.removeTransactionAction(byId: transaction.id)
            }
        } catch {
        }

        return .updated
    }

    func deleteTransaction(id: Int) async -> TransactionDeletionResult {
        let resource = DataResource.transaction(id)
        await InFlightDataRegistry.shared.acquire(resource)
        let result = await deleteTransactionWhileInFlight(id: id)
        await InFlightDataRegistry.shared.end(resource)
        if result == .deleted {
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
            NotificationCenter.default.post(name: .accountsDidChange, object: nil)
        }
        return result
    }

    private func deleteTransactionWhileInFlight(id: Int) async -> TransactionDeletionResult {
        let localResult = await DataMutationCoordinator.shared.withLock {
            await deleteLocalTransaction(id: id)
        }

        guard localResult == .deleted else { return localResult }

        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        NotificationCenter.default.post(name: .accountsDidChange, object: nil)

        guard NetworkMonitor.shared.isConnected, !isTemporaryTransactionID(id) else {
            return .deleted
        }

        do {
            try await network.delete(endpoint: "/transactions/\(id)")
            try await DataMutationCoordinator.shared.withLock {
                try backup.removeTransactionAction(byId: id)
            }
        } catch {
            if isPermanentSyncError(error),
               await restoreRejectedTransactionDeletion(id: id) {
                return .failed
            }
        }

        return .deleted
    }

    private func applyLocalTransactionUpdate(_ transaction: Transaction) async -> TransactionUpdateResult {

        let oldTransaction: Transaction
        let originalAccounts: [Int: BankAccount]
        let projectedBalances: [Int: Decimal]

        do {
            guard let storedTransaction = try await storage.fetch(byIds: [transaction.id]).first else {
                return .failed
            }
            guard storedTransaction.amount > 0 else { return .failed }
            oldTransaction = storedTransaction

            guard let accounts = try await fetchAffectedAccounts(
                current: oldTransaction,
                updated: transaction
            ) else {
                return .failed
            }
            originalAccounts = accounts

            let balances = accounts.mapValues(\.balance)
            guard let projected = TransactionBalanceValidator.projectedBalances(
                replacing: oldTransaction,
                with: transaction,
                accountBalances: balances
            ) else {
                return .failed
            }
            guard projected.values.allSatisfy({ $0 >= 0 }) else {
                return .insufficientFunds
            }
            projectedBalances = projected
        } catch {
            return .failed
        }

        guard await applyLocalUpdate(
            transaction,
            originalAccounts: originalAccounts,
            projectedBalances: projectedBalances
        ) else {
            return .failed
        }

        do {
            try backup.addTransactionAction(transaction, action: .update)
        } catch {
            await rollbackLocalUpdate(oldTransaction, originalAccounts: originalAccounts)
            return .failed
        }

        return .updated
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
                let accountsService = BankAccountsService()
                _ = await accountsService.fetchAccounts()
                let hadPendingTransactions = (try? await DataMutationCoordinator.shared.withLock {
                    let actions = try backup.fetchAllTransactionActions()
                    return !actions.isEmpty
                }) ?? false
                await syncBackupToBackend()
                if hadPendingTransactions {
                    _ = await accountsService.fetchAccounts()
                }
            } while Self.syncRequested
        }
        
        await Self.syncTask?.value
    }
    
    private func balanceDelta(for transaction: Transaction) -> Decimal {
        transaction.direction == .income ? transaction.amount : -transaction.amount
    }

    private func createLocalTransaction(_ transaction: Transaction) async -> TransactionCreationResult {
        let account: BankAccount

        do {
            guard let storedAccount = try await accountsStorage.fetch(byId: transaction.accountId) else {
                return .accountNotFound
            }
            account = storedAccount
        } catch {
            return .failed
        }

        let projectedBalance = account.balance + balanceDelta(for: transaction)
        guard projectedBalance >= 0 else { return .insufficientFunds }

        do {
            try await storage.create(transaction)
            do {
                try await accountsStorage.update(account.withBalance(projectedBalance))
                try backup.addTransactionAction(transaction, action: .create)
                return .created
            } catch {
                try? await storage.delete(byId: transaction.id)
                try? await accountsStorage.update(account)
                try? backup.removeTransactionAction(byId: transaction.id)
                return .failed
            }
        } catch {
            return .failed
        }
    }

    private func deleteLocalTransaction(id: Int) async -> TransactionDeletionResult {
        let transaction: Transaction
        let account: BankAccount

        do {
            guard let storedTransaction = try await storage.fetch(byIds: [id]).first else {
                return .deleted
            }
            transaction = storedTransaction
            guard transaction.amount > 0 else { return .failed }
            guard let storedAccount = try await accountsStorage.fetch(byId: transaction.accountId) else {
                return .failed
            }
            account = storedAccount
        } catch {
            return .failed
        }

        let projectedBalance = account.balance - balanceDelta(for: transaction)
        guard projectedBalance >= 0 else { return .insufficientFunds }

        do {
            try await storage.delete(byId: id)
            do {
                try await accountsStorage.update(account.withBalance(projectedBalance))
                try backup.addTransactionAction(transaction, action: .delete)
                return .deleted
            } catch {
                try? await storage.update(transaction)
                try? await accountsStorage.update(account)
                return .failed
            }
        } catch {
            return .failed
        }
    }

    private func fetchAffectedAccounts(
        current: Transaction,
        updated: Transaction
    ) async throws -> [Int: BankAccount]? {
        let accountIDs = Set([current.accountId, updated.accountId])
        var accounts: [Int: BankAccount] = [:]

        for id in accountIDs {
            guard let account = try await accountsStorage.fetch(byId: id) else { return nil }
            accounts[id] = account
        }

        return accounts
    }

    private func applyLocalUpdate(
        _ transaction: Transaction,
        originalAccounts: [Int: BankAccount],
        projectedBalances: [Int: Decimal]
    ) async -> Bool {
        var persistedAccountIDs: [Int] = []

        do {
            for id in projectedBalances.keys.sorted() {
                guard let account = originalAccounts[id],
                      let balance = projectedBalances[id] else {
                    throw NetworkError.noData
                }
                try await accountsStorage.update(account.withBalance(balance))
                persistedAccountIDs.append(id)
            }

            try await storage.update(transaction)
            return true
        } catch {
            for id in persistedAccountIDs.reversed() {
                if let account = originalAccounts[id] {
                    try? await accountsStorage.update(account)
                }
            }
            return false
        }
    }

    private func rollbackLocalUpdate(
        _ transaction: Transaction,
        originalAccounts: [Int: BankAccount]
    ) async {
        try? await storage.update(transaction)
        for account in originalAccounts.values {
            try? await accountsStorage.update(account)
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

    private func syncPendingUpdate(_ transaction: Transaction) async -> Bool {
        let resource = DataResource.transaction(transaction.id)
        guard await InFlightDataRegistry.shared.begin(resource) else { return false }
        let result = await syncPendingUpdateWhileInFlight(transaction)
        await InFlightDataRegistry.shared.end(resource)
        return result
    }

    private func syncPendingUpdateWhileInFlight(_ transaction: Transaction) async -> Bool {

        var currentServerTransaction: Transaction?
        var serverAccounts: [Int: BankAccount] = [:]

        do {
            let currentDTO: TransactionResponseDTO = try await network.get(
                endpoint: "/transactions/\(transaction.id)",
                reportsActivity: false,
                presentsError: false
            )
            let current = currentDTO.toDomain(fallbackDirection: transaction.direction)
            currentServerTransaction = current
            let accountDTOs: [BankAccountDTO] = try await network.get(
                endpoint: "/accounts",
                reportsActivity: false,
                presentsError: false
            )
            serverAccounts = Dictionary(
                uniqueKeysWithValues: accountDTOs.map { ($0.id, $0.toDomain()) }
            )

            guard let projected = TransactionBalanceValidator.projectedBalances(
                replacing: current,
                with: transaction,
                accountBalances: serverAccounts.mapValues(\.balance)
            ) else {
                return false
            }

            if !projected.values.allSatisfy({ $0 >= 0 }) {
                do {
                    try await DataMutationCoordinator.shared.withLock {
                        try await storage.update(current)
                        for id in Set([current.accountId, transaction.accountId]) {
                            if let account = serverAccounts[id] {
                                try await accountsStorage.update(account)
                            }
                        }
                        try backup.removeTransactionAction(byId: transaction.id)
                    }
                    return true
                } catch {
                    return false
                }
            }

            let request = TransactionRequestDTO(from: transaction)
            try await network.send(
                endpoint: "/transactions/\(transaction.id)",
                method: .put,
                body: request,
                reportsActivity: false,
                presentsError: false
            )
            try await DataMutationCoordinator.shared.withLock {
                try backup.removeTransactionAction(byId: transaction.id)
            }
            return true
        } catch {
            guard isPermanentSyncError(error) else {
                return false
            }

            do {
                try await DataMutationCoordinator.shared.withLock {
                    if let networkError = error as? NetworkError,
                       case .notFound = networkError {
                        try await storage.delete(byId: transaction.id)
                    } else if let currentServerTransaction {
                        try await storage.update(currentServerTransaction)
                    } else {
                        throw NetworkError.noData
                    }
                    for account in serverAccounts.values {
                        try await accountsStorage.update(account)
                    }
                    try backup.removeTransactionAction(byId: transaction.id)
                }
                return true
            } catch {
                return false
            }
        }
    }

    private func isTemporaryTransactionID(_ id: Int) -> Bool {
        id > 1_000_000_000
    }
    
    private func mergeAndFilter(
        local: [Transaction],
        backup: [Transaction],
        excluding deletedIDs: Set<Int> = [],
        from startDate: Date,
        to endDate: Date
    ) -> [Transaction] {
        var merged: [Int: Transaction] = [:]
        for t in local where !deletedIDs.contains(t.id) { merged[t.id] = t }
        for t in backup { merged[t.id] = t }
        
        let result = Array(merged.values)
        return result.filter {
            $0.transactionDate >= startDate && $0.transactionDate < endDate
        }
    }
    
    private func syncBackupToBackend() async {
        guard NetworkMonitor.shared.isConnected else { return }
        guard let actions = try? await DataMutationCoordinator.shared.withLock({
            try backup.fetchAllTransactionActions()
        }) else { return }
        guard !actions.isEmpty else { return }

        var didSync = false

        for action in actions {
            let transaction = action.toTransaction()

            switch action.actionType {
            case .create:
                didSync = await syncPendingCreate(transaction) || didSync

            case .update:
                if isTemporaryTransactionID(transaction.id) {
                    try? await DataMutationCoordinator.shared.withLock {
                        try backup.removeTransactionAction(byId: transaction.id)
                    }
                    didSync = true
                } else {
                    didSync = await syncPendingUpdate(transaction) || didSync
                }

            case .delete:
                didSync = await syncPendingDelete(transaction) || didSync
            }
        }

        if didSync {
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
            NotificationCenter.default.post(name: .accountsDidChange, object: nil)
        }
    }

    private func syncPendingCreate(_ transaction: Transaction) async -> Bool {
        let resource = DataResource.transaction(transaction.id)
        guard await InFlightDataRegistry.shared.begin(resource) else { return false }

        let result: Bool
        if isTemporaryTransactionID(transaction.accountId) {
            result = false
        } else {
            let request = TransactionRequestDTO(from: transaction)
            do {
                let dto: TransactionCreatedDTO = try await network.request(
                    endpoint: "/transactions",
                    method: .post,
                    body: request,
                    reportsActivity: false,
                    presentsError: false
                )
                let created = dto.toDomain(direction: transaction.direction)
                try await DataMutationCoordinator.shared.withLock {
                    try await storage.delete(byId: transaction.id)
                    try await storage.update(created)
                    try backup.removeTransactionAction(byId: transaction.id)
                }
                result = true
            } catch {
                result = false
            }
        }

        await InFlightDataRegistry.shared.end(resource)
        return result
    }

    private func syncPendingDelete(_ transaction: Transaction) async -> Bool {
        let resource = DataResource.transaction(transaction.id)
        guard await InFlightDataRegistry.shared.begin(resource) else { return false }

        let result: Bool
        if isTemporaryTransactionID(transaction.id) {
            do {
                try await DataMutationCoordinator.shared.withLock {
                    try backup.removeTransactionAction(byId: transaction.id)
                }
                result = true
            } catch {
                result = false
            }
        } else {
            do {
                try await network.delete(
                    endpoint: "/transactions/\(transaction.id)",
                    reportsActivity: false,
                    presentsError: false
                )
                try await DataMutationCoordinator.shared.withLock {
                    try await storage.delete(byId: transaction.id)
                    try backup.removeTransactionAction(byId: transaction.id)
                }
                result = true
            } catch {
                if isPermanentSyncError(error) {
                    result = await restoreRejectedTransactionDeletion(id: transaction.id)
                } else {
                    result = false
                }
            }
        }

        await InFlightDataRegistry.shared.end(resource)
        return result
    }

    private func restoreRejectedTransactionDeletion(id: Int) async -> Bool {
        do {
            let dto: TransactionResponseDTO = try await network.get(
                endpoint: "/transactions/\(id)",
                reportsActivity: false,
                presentsError: false
            )
            let actions = try await DataMutationCoordinator.shared.withLock {
                try backup.fetchAllTransactionActions()
            }
            guard let action = actions.first(where: { $0.transactionId == id }) else {
                return false
            }
            let transaction = dto.toDomain(fallbackDirection: action.toTransaction().direction)
            let accountDTOs: [BankAccountDTO] = try await network.get(
                endpoint: "/accounts",
                reportsActivity: false,
                presentsError: false
            )
            let account = accountDTOs.first(where: { $0.id == transaction.accountId })?.toDomain()

            try await DataMutationCoordinator.shared.withLock {
                try await storage.update(transaction)
                if let account {
                    try await accountsStorage.update(account)
                }
                try backup.removeTransactionAction(byId: id)
            }
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
            NotificationCenter.default.post(name: .accountsDidChange, object: nil)
            return true
        } catch {
            return false
        }
    }
}

private extension BankAccount {
    func withBalance(_ balance: Decimal) -> BankAccount {
        BankAccount(
            id: id,
            userId: userId,
            name: name,
            emoji: emoji,
            balance: balance,
            currency: currency,
            createdAt: createdAt,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}
