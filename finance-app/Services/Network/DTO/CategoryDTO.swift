import Foundation

struct CategoryDTO: Codable {
    let id: Int
    let name: String
    let emoji: String
    let isIncome: Bool
    
    func toDomain() -> Category {
        Category(
            id: id,
            name: name,
            emoji: Character(emoji),
            isIncome: isIncome
        )
    }
}
