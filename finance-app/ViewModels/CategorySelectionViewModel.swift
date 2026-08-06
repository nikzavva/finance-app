import Combine
import Foundation

@MainActor
final class CategorySelectionViewModel: ObservableObject {
    @Published private(set) var categories: [Category] = []
    @Published var searchText = ""

    private let direction: Direction
    private let categoriesService: CategoriesServicing

    init(
        direction: Direction,
        categoriesService: CategoriesServicing? = nil
    ) {
        self.direction = direction
        self.categoriesService = categoriesService ?? CategoriesService()
    }

    var filteredCategories: [Category] {
        guard !searchText.isEmpty else { return categories }
        let words = searchText.lowercased().split(separator: " ").map(String.init)
        return categories.filter { category in
            let name = category.name.lowercased()
            return words.allSatisfy { name.contains($0) }
        }
    }

    func load() async {
        let loadedCategories = await categoriesService.fetchCategories(direction: direction)
        guard !Task.isCancelled else { return }
        categories = loadedCategories
    }
}
