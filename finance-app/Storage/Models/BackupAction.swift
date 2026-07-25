import Foundation
import SwiftData

enum BackupActionType: String, Codable {
    case create
    case update
    case delete
}

@Model
final class BackupTransactionAction {
    @Attribute(.unique) var transactionId: Int
    var actionTypeRaw: String
    var accountId: Int
    var categoryId: Int
    var amount: Decimal
    var transactionDate: Date
    var comment: String?
    var createdAt: String?
    var updatedAt: String?
    var directionRaw: String
    
    var actionType: BackupActionType {
        BackupActionType(rawValue: actionTypeRaw) ?? .create
    }
    
    init(transaction: Transaction, action: BackupActionType) {
        self.transactionId = transaction.id
        self.actionTypeRaw = action.rawValue
        self.accountId = transaction.accountId
        self.categoryId = transaction.categoryId
        self.amount = transaction.amount
        self.transactionDate = transaction.transactionDate
        self.comment = transaction.comment
        self.createdAt = transaction.createdAt
        self.updatedAt = transaction.updatedAt
        self.directionRaw = transaction.direction.rawValue
    }
    
    func toTransaction() -> Transaction {
        Transaction(
            id: transactionId,
            accountId: accountId,
            categoryId: categoryId,
            amount: amount,
            transactionDate: transactionDate,
            comment: comment,
            createdAt: createdAt,
            updatedAt: updatedAt,
            direction: Direction(rawValue: directionRaw) ?? .outcome
        )
    }
}

@Model
final class BackupAccountAction {
    @Attribute(.unique) var accountId: Int
    var actionTypeRaw: String
    var userId: Int
    var name: String
    var emoji: String
    var balance: Decimal
    var currency: String
    var createdAt: String
    var updatedAt: String
    
    var actionType: BackupActionType {
        BackupActionType(rawValue: actionTypeRaw) ?? .create
    }
    
    init(account: BankAccount, action: BackupActionType) {
        self.accountId = account.id
        self.actionTypeRaw = action.rawValue
        self.userId = account.userId
        self.name = account.name
        self.emoji = account.emoji
        self.balance = account.balance
        self.currency = account.currency
        self.createdAt = account.createdAt
        self.updatedAt = account.updatedAt
    }
    
    func toAccount() -> BankAccount {
        BankAccount(
            id: accountId,
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
