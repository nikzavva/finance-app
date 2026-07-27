import Foundation
import CoreData

@objc(AccountEntity)
public class AccountMO: NSManagedObject {
    @NSManaged public var id: Int64
    @NSManaged public var userId: Int64
    @NSManaged public var name: String
    @NSManaged public var emoji: String
    @NSManaged public var balance: NSDecimalNumber
    @NSManaged public var currency: String
    @NSManaged public var createdAt: String
    @NSManaged public var updatedAt: String
    
    func fill(from account: BankAccount) {
        self.id = Int64(account.id)
        self.userId = Int64(account.userId)
        self.name = account.name
        self.emoji = account.emoji
        self.balance = account.balance as NSDecimalNumber
        self.currency = account.currency
        self.createdAt = account.createdAt
        self.updatedAt = account.updatedAt
    }
    
    func toDomain() -> BankAccount {
        BankAccount(
            id: Int(id),
            userId: Int(userId),
            name: name,
            emoji: emoji,
            balance: balance as Decimal,
            currency: currency,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AccountMO> {
        NSFetchRequest<AccountMO>(entityName: "AccountEntity")
    }
}
