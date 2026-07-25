import Foundation
import SwiftData

@Model
final class CategoryEntity {
    @Attribute(.unique) var id: Int
    var name: String
    var emoji: String
    var isIncome: Bool
    
    init(category: Category) {
        self.id = category.id
        self.name = category.name
        self.emoji = String(category.emoji)
        self.isIncome = category.isIncome
    }
    
    func toDomain() -> Category {
        Category(
            id: id,
            name: name,
            emoji: Character(emoji),
            isIncome: isIncome
        )
    }
}
