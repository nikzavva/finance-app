import Foundation
import CoreData

@objc(CategoryEntity)
public class CategoryMO: NSManagedObject {
    @NSManaged public var id: Int64
    @NSManaged public var name: String
    @NSManaged public var emoji: String
    @NSManaged public var isIncome: Bool
    
    func fill(from category: Category) {
        self.id = Int64(category.id)
        self.name = category.name
        self.emoji = String(category.emoji)
        self.isIncome = category.isIncome
    }
    
    func toDomain() -> Category {
        Category(
            id: Int(id),
            name: name,
            emoji: Character(emoji),
            isIncome: isIncome
        )
    }
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CategoryMO> {
        NSFetchRequest<CategoryMO>(entityName: "CategoryEntity")
    }
}
