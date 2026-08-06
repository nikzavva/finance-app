import Foundation

final class CategoriesService {
    private let network = NetworkClient.shared
    private var storage: CategoriesStorage { StorageManager.shared.categoriesStorage }
    
    func fetchAllCategories() async -> [Category] {
        guard NetworkMonitor.shared.isConnected else {
            return sorted(await fetchLocalCategories())
        }
        
        do {
            let dtos: [CategoryDTO] = try await network.get(endpoint: "/categories")
            let categories = sorted(dtos.map { $0.toDomain() })
            try? await DataMutationCoordinator.shared.withLock {
                try await storage.save(categories)
            }
            return categories
        } catch {
            return sorted(await fetchLocalCategories())
        }
    }
    
    func fetchCategories(direction: Direction) async -> [Category] {
        let isIncome = direction == .income
        
        guard NetworkMonitor.shared.isConnected else {
            let local = await fetchLocalCategories()
            return sorted(local.filter { $0.isIncome == isIncome })
        }
        
        do {
            let dtos: [CategoryDTO] = try await network.get(endpoint: "/categories/type/\(isIncome)")
            let categories = sorted(dtos.map { $0.toDomain() })
            
            try? await DataMutationCoordinator.shared.withLock {
                let all = try await storage.fetchAll()
                let other = all.filter { $0.isIncome != isIncome }
                try await storage.save(sorted(other + categories))
            }
            
            return categories
        } catch {
            let local = await fetchLocalCategories()
            return sorted(local.filter { $0.isIncome == isIncome })
        }
    }

    private func fetchLocalCategories() async -> [Category] {
        (try? await DataMutationCoordinator.shared.withLock {
            try await storage.fetchAll()
        }) ?? []
    }

    private func sorted(_ categories: [Category]) -> [Category] {
        categories.sorted {
            let comparison = $0.name.localizedCaseInsensitiveCompare($1.name)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }
}
