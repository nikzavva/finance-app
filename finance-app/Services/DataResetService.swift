import Foundation

enum DataResetError: LocalizedError {
    case offline
    case failed

    var errorDescription: String? {
        switch self {
        case .offline:
            "Для удаления данных требуется подключение к интернету.".appLocalized
        case .failed:
            "Не удалось удалить данные".appLocalized
        }
    }
}

final class DataResetService {
    private let network: NetworkClient
    private let storageManager: StorageManager

    init(
        network: NetworkClient = .shared,
        storageManager: StorageManager = .shared
    ) {
        self.network = network
        self.storageManager = storageManager
    }

    func deleteAllUserData() async throws {
        guard NetworkMonitor.shared.isConnected else {
            throw DataResetError.offline
        }

        do {
            let accounts: [BankAccountDTO] = try await network.get(
                endpoint: "/accounts",
                reportsActivity: false,
                presentsError: false
            )

            for account in accounts {
                let transactions: [TransactionDTO] = try await network.get(
                    endpoint: "/transactions/account/\(account.id)/period",
                    queryItems: [
                        URLQueryItem(name: "startDate", value: "1970-01-01"),
                        URLQueryItem(name: "endDate", value: "2100-01-01")
                    ],
                    reportsActivity: false,
                    presentsError: false
                )

                for transaction in transactions.sorted(by: { !$0.category.isIncome && $1.category.isIncome }) {
                    try await network.delete(
                        endpoint: "/transactions/\(transaction.id)",
                        reportsActivity: false,
                        presentsError: false
                    )
                }
            }

            for account in accounts {
                try await network.delete(
                    endpoint: "/accounts/\(account.id)",
                    reportsActivity: false,
                    presentsError: false
                )
            }

            try await storageManager.clearUserData()
            NetworkMonitor.shared.markDataFresh()
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
            NotificationCenter.default.post(name: .accountsDidChange, object: nil)
        } catch let error as DataResetError {
            throw error
        } catch {
            throw DataResetError.failed
        }
    }
}
