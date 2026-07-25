import Foundation

final class BankAccountsService {
    private let network = NetworkClient.shared
    
    func fetchAccounts() async throws -> [BankAccount] {
        let dtos: [BankAccountDTO] = try await network.get(endpoint: "/accounts")
        return dtos.map { $0.toDomain() }
    }
    
    func createAccount(_ account: BankAccount) async throws -> BankAccount {
        let request = CreateAccountRequestDTO(from: account)
        let dto: BankAccountDTO = try await network.request(
            endpoint: "/accounts",
            method: .post,
            body: request
        )
        return dto.toDomain()
    }
    
    func updateAccount(_ account: BankAccount) async throws -> BankAccount {
        let request = UpdateAccountRequestDTO(from: account)
        let dto: BankAccountDTO = try await network.request(
            endpoint: "/accounts/\(account.id)",
            method: .put,
            body: request
        )
        return dto.toDomain()
    }
    
    func deleteAccount(id: Int) async throws {
        try await network.delete(endpoint: "/accounts/\(id)")
    }
}
