import SwiftUI

struct FinanceAppView: View {
    @StateObject private var viewModel = FinanceAppViewModel()
    
    var body: some View {
        NavigationStack {
            TabView(selection: $viewModel.selectedTab) {
                TransactionsListView(
                    direction: .outcome,
                    selectedDate: $viewModel.selectedDate,
                    selectedCategory: $viewModel.outcomeCategory
                )
                .tabItem {
                    Label("Расходы", systemImage: "arrow.down.circle")
                        .environment(\.symbolVariants, .none)
                }
                .tag(FinanceAppViewModel.Tab.outcome)

                TransactionsListView(
                    direction: .income,
                    selectedDate: $viewModel.selectedDate,
                    selectedCategory: $viewModel.incomeCategory
                )
                .tabItem {
                    Label("Доходы", systemImage: "arrow.up.circle")
                        .environment(\.symbolVariants, .none)
                }
                .tag(FinanceAppViewModel.Tab.income)

                BankAccountsView()
                    .tabItem {
                        Label("Счета", systemImage: "wallet.bifold")
                            .environment(\.symbolVariants, .none)
                    }
                    .tag(FinanceAppViewModel.Tab.accounts)
            }
            .toolbar {
                switch viewModel.selectedTab {
                case .outcome, .income:
                    CommonToolbar(
                        direction: viewModel.selectedDirection,
                        selectedDate: $viewModel.selectedDate,
                        showDatePicker: $viewModel.showDatePicker,
                        showSettings: $viewModel.showSettings
                    )
                case .accounts:
                    AccountsToolbar(showSettings: $viewModel.showSettings)
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .analytics(let direction):
                    AnalyticsView(initialDirection: direction)
                        .toolbar(.hidden, for: .navigationBar)
                        .toolbar(.hidden, for: .tabBar)
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView(
                    categoryDirection: viewModel.selectedTab == .accounts
                        ? nil
                        : viewModel.selectedDirection
                ) { category, direction in
                    viewModel.selectCategory(category, for: direction)
                }
            }
        }
        .tint(Color.accentColor)
    }
}

#Preview {
    FinanceAppView()
}
