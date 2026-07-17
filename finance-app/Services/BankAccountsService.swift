import Foundation

final class BankAccountsService {
    private var accounts: [BankAccount] = [
        BankAccount(id: 1, userId: 1, name: "Яндекс Пэй", balance: 15000, currency: "RUB", createdAt: "", updatedAt: ""),
        BankAccount(id: 2, userId: 1, name: "Сбербанк", balance: 8000, currency: "RUB", createdAt: "", updatedAt: ""),
        BankAccount(id: 3, userId: 1, name: "Газпромбанк", balance: 3000, currency: "RUB", createdAt: "", updatedAt: "")
    ]
    
    func fetchAccounts() async -> [BankAccount] {
        return accounts
    }
    
    func fetchAccount(id: Int) async -> BankAccount? {
        return accounts.first { $0.id == id }
    }
    
    func updateAccount(_ account: BankAccount) async -> BankAccount? {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            return account
        }
        return nil
    }
}
