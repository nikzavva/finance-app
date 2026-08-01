import Foundation
import SwiftData

@Model
final class AccountEntity {
    @Attribute(.unique) var id: Int
    var userId: Int
    var name: String
    var emoji: String
    var balance: Decimal
    var currency: String
    var createdAt: String
    var updatedAt: String
    
    init(account: BankAccount) {
        self.id = account.id
        self.userId = account.userId
        self.name = account.name
        self.emoji = account.emoji
        self.balance = account.balance
        self.currency = account.currency
        self.createdAt = account.createdAt
        self.updatedAt = account.updatedAt
    }
    
    func toDomain() -> BankAccount {
        BankAccount(
            id: id,
            userId: userId,
            name: name,
            emoji: emoji,
            balance: balance,
            currency: currency,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
