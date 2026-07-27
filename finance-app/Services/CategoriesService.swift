import Foundation

final class CategoriesService {
    private let network = NetworkClient.shared
    private var storage: CategoriesStorage { StorageManager.shared.categoriesStorage }
    
    func fetchAllCategories() async -> [Category] {
        guard NetworkMonitor.shared.isConnected else {
            return (try? await storage.fetchAll()) ?? []
        }
        
        do {
            let dtos: [CategoryDTO] = try await network.get(endpoint: "/categories")
            let categories = dtos.map { $0.toDomain() }
            try? await storage.save(categories)
            return categories
        } catch {
            return (try? await storage.fetchAll()) ?? []
        }
    }
    
    func fetchCategories(direction: Direction) async -> [Category] {
        let isIncome = direction == .income
        
        guard NetworkMonitor.shared.isConnected else {
            let local = (try? await storage.fetchAll()) ?? []
            return local.filter { $0.isIncome == isIncome }
        }
        
        do {
            let dtos: [CategoryDTO] = try await network.get(endpoint: "/categories/type/\(isIncome)")
            let categories = dtos.map { $0.toDomain() }
            
            let all = (try? await storage.fetchAll()) ?? []
            let other = all.filter { $0.isIncome != isIncome }
            try? await storage.save(other + categories)
            
            return categories
        } catch {
            let local = (try? await storage.fetchAll()) ?? []
            return local.filter { $0.isIncome == isIncome }
        }
    }
}
