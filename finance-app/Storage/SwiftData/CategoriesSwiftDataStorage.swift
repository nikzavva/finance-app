import Foundation
import SwiftData

final class CategoriesSwiftDataStorage: CategoriesStorage {
    private let container: ModelContainer
    
    init(container: ModelContainer) {
        self.container = container
    }
    
    func fetchAll() async throws -> [Category] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CategoryEntity>()
        let entities = try context.fetch(descriptor)
        return entities.map { $0.toDomain() }
    }
    
    func save(_ categories: [Category]) async throws {
        let context = ModelContext(container)
        try context.delete(model: CategoryEntity.self)
        for category in categories {
            context.insert(CategoryEntity(category: category))
        }
        try context.save()
    }
}
