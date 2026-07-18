final class CategoriesService {
    private let allCategories: [Category] = [
        Category(id: 1, name: "Канцтовары", emoji: "✏️", isIncome: false),
        Category(id: 2, name: "Кафе", emoji: "☕️", isIncome: false),
        Category(id: 3, name: "Топливо", emoji: "⛽️", isIncome: false),
        Category(id: 4, name: "Подписки", emoji: "📱", isIncome: false),
        Category(id: 5, name: "Ремонт", emoji: "🔧", isIncome: false),
        Category(id: 6, name: "Билеты", emoji: "🎫", isIncome: false),
        Category(id: 7, name: "Интернет", emoji: "🌐", isIncome: false),
        Category(id: 8, name: "Продукты", emoji: "🛒", isIncome: false),
        Category(id: 9, name: "Мебель", emoji: "🛋️", isIncome: true),
        Category(id: 10, name: "Налоги", emoji: "📋", isIncome: true),
        Category(id: 11, name: "Премия", emoji: "💼", isIncome: true),
        Category(id: 12, name: "Фриланс", emoji: "💻", isIncome: true),
        Category(id: 13, name: "Аренда", emoji: "🏠", isIncome: true),
        Category(id: 14, name: "Кэшбэк", emoji: "💳", isIncome: true),
        Category(id: 15, name: "Подарки", emoji: "🎁", isIncome: true)
    ]
    
    func fetchAllCategories() async -> [Category] {
        return allCategories
    }
    
    func fetchCategories(direction: Direction) async -> [Category] {
        return allCategories.filter { $0.direction == direction }
    }
}
