import Foundation

final class TransactionsService {
    private let network = NetworkClient.shared
    
    func fetchTransactions(from startDate: Date, to endDate: Date, accountId: Int? = nil) async throws -> [Transaction] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let queryItems: [URLQueryItem]
        if let accountId = accountId {
            let endpoint = "/transactions/account/\(accountId)/period"
            queryItems = [
                URLQueryItem(name: "startDate", value: dateFormatter.string(from: startDate)),
                URLQueryItem(name: "endDate", value: dateFormatter.string(from: endDate))
            ]
            let dtos: [TransactionDTO] = try await network.get(endpoint: endpoint, queryItems: queryItems)
            return dtos.map { $0.toDomain() }
        } else {
            throw NetworkError.notFound
        }
    }
    
    func fetchTransactionsByAccount(accountId: Int, from startDate: Date, to endDate: Date) async throws -> [Transaction] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let queryItems = [
            URLQueryItem(name: "startDate", value: dateFormatter.string(from: startDate)),
            URLQueryItem(name: "endDate", value: dateFormatter.string(from: endDate))
        ]
        
        let dtos: [TransactionDTO] = try await network.get(
            endpoint: "/transactions/account/\(accountId)/period",
            queryItems: queryItems
        )
        return dtos.map { $0.toDomain() }
    }
    
    func createTransaction(_ transaction: Transaction) async throws -> Transaction {
        let request = TransactionRequestDTO(from: transaction)
        let dto: TransactionCreatedDTO = try await network.request(
            endpoint: "/transactions",
            method: .post,
            body: request
        )
        return dto.toDomain(direction: transaction.direction)
    }

    func updateTransaction(_ transaction: Transaction) async throws -> Transaction {
        let request = TransactionRequestDTO(from: transaction)
        let dto: TransactionCreatedDTO = try await network.request(
            endpoint: "/transactions/\(transaction.id)",
            method: .put,
            body: request
        )
        return dto.toDomain(direction: transaction.direction)
    }
    
    func deleteTransaction(id: Int) async throws {
        try await network.delete(endpoint: "/transactions/\(id)")
    }
}
