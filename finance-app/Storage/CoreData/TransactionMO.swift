import Foundation
import CoreData

@objc(TransactionEntity)
public class TransactionMO: NSManagedObject {
    @NSManaged public var id: Int64
    @NSManaged public var accountId: Int64
    @NSManaged public var categoryId: Int64
    @NSManaged public var amount: NSDecimalNumber
    @NSManaged public var transactionDate: Date
    @NSManaged public var comment: String?
    @NSManaged public var createdAt: String?
    @NSManaged public var updatedAt: String?
    @NSManaged public var directionRaw: String
    
    func fill(from transaction: Transaction) {
        self.id = Int64(transaction.id)
        self.accountId = Int64(transaction.accountId)
        self.categoryId = Int64(transaction.categoryId)
        self.amount = transaction.amount as NSDecimalNumber
        self.transactionDate = transaction.transactionDate
        self.comment = transaction.comment
        self.createdAt = transaction.createdAt
        self.updatedAt = transaction.updatedAt
        self.directionRaw = transaction.direction.rawValue
    }
    
    func toDomain() -> Transaction {
        Transaction(
            id: Int(id),
            accountId: Int(accountId),
            categoryId: Int(categoryId),
            amount: amount as Decimal,
            transactionDate: transactionDate,
            comment: comment,
            createdAt: createdAt,
            updatedAt: updatedAt,
            direction: Direction(rawValue: directionRaw) ?? .outcome
        )
    }
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TransactionMO> {
        NSFetchRequest<TransactionMO>(entityName: "TransactionEntity")
    }
}
