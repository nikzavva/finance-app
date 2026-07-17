final class CategoriesService {
    private let allCategories: [Category] = [
        Category(id: 1, name: "Зарплата", emoji: "💰", isIncome: true),
        Category(id: 2, name: "Фриланс", emoji: "💻", isIncome: true),
        Category(id: 3, name: "Подарки", emoji: "🎁", isIncome: true),
        Category(id: 4, name: "Еда", emoji: "🍕", isIncome: false),
        Category(id: 5, name: "Транспорт", emoji: "🚌", isIncome: false),
        Category(id: 6, name: "Развлечения", emoji: "🎮", isIncome: false)
    ]
    
    func fetchAllCategories() async -> [Category] {
        return allCategories
    }
    
    func fetchCategories(direction: Direction) async -> [Category] {
        return allCategories.filter { $0.direction == direction }
    }
}
