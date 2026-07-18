import SwiftUI

struct FinanceAppView: View {
    @State private var selectedDate: Date = Date()
    
    var body: some View {
        TabView {
            TransactionsListView(direction: .outcome, selectedDate: $selectedDate)
                .tabItem {
                    Label("Расходы", systemImage: "arrow.down.circle")
                        .environment(\.symbolVariants, .none)
                }
            TransactionsListView(direction: .income, selectedDate: $selectedDate)
                .tabItem {
                    Label("Доходы", systemImage: "arrow.up.circle")
                        .environment(\.symbolVariants, .none)
                }
            BankAccountsView(selectedDate: $selectedDate)
                .tabItem {
                    Label("Счета", systemImage: "wallet.bifold")
                        .environment(\.symbolVariants, .none)
                }
        }
        .tint(Color("AccentColor"))
    }
}

#Preview {
    FinanceAppView()
        .environment(\.locale, Locale(identifier: "ru_RU"))
}
