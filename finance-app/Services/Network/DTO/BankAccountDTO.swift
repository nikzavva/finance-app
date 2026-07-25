import Foundation

struct BankAccountDTO: Codable {
    let id: Int
    let userId: Int
    let name: String
    let emoji: String
    let balance: String
    let currency: String
    let createdAt: String
    let updatedAt: String
    
    func toDomain() -> BankAccount {
        BankAccount(
            id: id,
            userId: userId,
            name: name,
            emoji: emoji,
            balance: Decimal(string: balance) ?? 0,
            currency: currency,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
