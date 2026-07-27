import Foundation
import SwiftData

@Model
final class TransactionEntity {
    @Attribute(.unique) var id: Int
    var accountId: Int
    var categoryId: Int
    var amount: Decimal
    var transactionDate: Date
    var comment: String?
    var createdAt: String?
    var updatedAt: String?
    var directionRaw: String
    
    var direction: Direction {
        Direction(rawValue: directionRaw) ?? .outcome
    }
    
    init(transaction: Transaction) {
        self.id = transaction.id
        self.accountId = transaction.accountId
        self.categoryId = transaction.categoryId
        self.amount = transaction.amount
        self.transactionDate = transaction.transactionDate
        self.comment = transaction.comment
        self.createdAt = transaction.createdAt
        self.updatedAt = transaction.updatedAt
        self.directionRaw = transaction.direction.rawValue
    }
    
    func toDomain() -> Transaction {
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
