import Foundation

final class CategoriesService {
    private let network = NetworkClient.shared
    
    func fetchAllCategories() async throws -> [Category] {
        let dtos: [CategoryDTO] = try await network.get(endpoint: "/categories")
        return dtos.map { $0.toDomain() }
    }
    
    func fetchCategories(direction: Direction) async throws -> [Category] {
        let isIncome = direction == .income
        let dtos: [CategoryDTO] = try await network.get(endpoint: "/categories/type/\(isIncome)")
        return dtos.map { $0.toDomain() }
    }
}
