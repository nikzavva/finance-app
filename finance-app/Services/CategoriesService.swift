final class CategoriesService {
    private let allCategories: [Category] = [
        Category(id: 1, name: "Аренда квартиры", emoji: "🏠", isIncome: false),
        Category(id: 2, name: "Одежда", emoji: "👕", isIncome: false),
        Category(id: 3, name: "На собачку", emoji: "🐾", isIncome: false),
        Category(id: 4, name: "Ремонт квартиры", emoji: "🛠️", isIncome: false),
        Category(id: 5, name: "Продукты", emoji: "🛒", isIncome: false),
        Category(id: 6, name: "Спортзал", emoji: "🏋️", isIncome: false),
        Category(id: 7, name: "Медицина", emoji: "💊", isIncome: false),
        Category(id: 8, name: "Магазин продуктов", emoji: "🛍️", isIncome: false),
        Category(id: 9, name: "Зарплата", emoji: "💰", isIncome: true),
        Category(id: 10, name: "Фриланс", emoji: "💻", isIncome: true),
        Category(id: 11, name: "Премия", emoji: "🎖️", isIncome: true),
        Category(id: 12, name: "Подработка", emoji: "📋", isIncome: true),
        Category(id: 13, name: "Аренда", emoji: "🏠", isIncome: true),
        Category(id: 14, name: "Кэшбэк", emoji: "💳", isIncome: true),
        Category(id: 15, name: "Подарки", emoji: "🎁", isIncome: true),
    ]
    
    func fetchAllCategories() async -> [Category] {
        return allCategories
    }
    
    func fetchCategories(direction: Direction) async -> [Category] {
        return allCategories.filter { $0.direction == direction }
    }
}
