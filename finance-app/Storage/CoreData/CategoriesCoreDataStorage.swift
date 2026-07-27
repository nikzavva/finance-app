import Foundation
import CoreData

final class CategoriesCoreDataStorage: CategoriesStorage {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    private var fetchRequest: NSFetchRequest<CategoryMO> {
        NSFetchRequest<CategoryMO>(entityName: "CategoryEntity")
    }
    
    func fetchAll() async throws -> [Category] {
        let results = try context.fetch(fetchRequest)
        return results.map { $0.toDomain() }
    }
    
    func save(_ categories: [Category]) async throws {
        let existing = try context.fetch(fetchRequest)
        existing.forEach { context.delete($0) }
        for category in categories {
            let mo = CategoryMO(context: context)
            mo.fill(from: category)
        }
        CoreDataStack.shared.saveContext()
    }
}
