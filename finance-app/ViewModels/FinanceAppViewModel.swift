import Combine
import Foundation

@MainActor
final class FinanceAppViewModel: ObservableObject {
    enum Tab: Hashable {
        case outcome
        case income
        case accounts
    }

    @Published var selectedDate = Date()
    @Published var selectedTab: Tab = .outcome
    @Published var showDatePicker = false
    @Published var showCategorySelection = false
    @Published var showSettings = false
    @Published var outcomeCategory: Category?
    @Published var incomeCategory: Category?

    var selectedDirection: Direction {
        selectedTab == .income ? .income : .outcome
    }

    var selectedCategory: Category? {
        switch selectedTab {
        case .outcome:
            outcomeCategory
        case .income:
            incomeCategory
        case .accounts:
            nil
        }
    }

    func selectCategory(_ category: Category, for direction: Direction) {
        switch direction {
        case .income:
            incomeCategory = incomeCategory?.id == category.id ? nil : category
        case .outcome:
            outcomeCategory = outcomeCategory?.id == category.id ? nil : category
        }
    }
}
