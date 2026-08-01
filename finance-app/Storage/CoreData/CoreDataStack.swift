import Foundation
import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()
    
    let persistentContainer: NSPersistentContainer
    
    private init() {
        let container = NSPersistentContainer(name: "FinanceModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Не удалось загрузить CoreData: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        self.persistentContainer = container
    }
    
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Ошибка сохранения CoreData: \(error)")
            }
        }
    }
    
    func clearAll() {
        let entities = persistentContainer.managedObjectModel.entities
        for entity in entities {
            guard let name = entity.name else { continue }
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: name)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            do {
                try persistentContainer.persistentStoreCoordinator.execute(deleteRequest, with: context)
            } catch {
                print("Ошибка очистки \(name): \(error)")
            }
        }
        saveContext()
    }
}
