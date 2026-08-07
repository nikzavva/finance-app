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
            let names = [category.name, category.localizedName].map { $0.lowercased() }
            return words.allSatisfy { word in
                names.contains { $0.contains(word) }
            }
        }
    }

    func load() async {
        let loadedCategories = await categoriesService.fetchCategories(direction: direction)
        guard !Task.isCancelled else { return }
        categories = loadedCategories
    }
}
