import SwiftUI

struct FinanceAppView: View {
    var body: some View {
        TabView {
            ExpensesView()
                .tabItem {
                    Label("Расходы", systemImage: "arrow.down.circle")
                        .environment(\.symbolVariants, .none)
                }
            IncomeView()
                .tabItem {
                    Label("Доходы", systemImage: "arrow.up.circle")
                        .environment(\.symbolVariants, .none)
                }
            AccountsView()
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
}
