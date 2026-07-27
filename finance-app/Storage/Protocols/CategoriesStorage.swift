protocol CategoriesStorage {
    func fetchAll() async throws -> [Category]
    func save(_ categories: [Category]) async throws
}
