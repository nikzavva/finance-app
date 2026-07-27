import SwiftUI

struct BankAccountsView: View {
    @Binding var selectedDate: Date
    
    @State private var accounts: [BankAccount] = []
    @State private var totalBalance: Decimal = 0
    @State private var showDatePicker = false
    @State private var showSettings = false
    @State private var showAddAccount = false
    @State private var selectedAccount: BankAccount?
    @State private var isBalanceHidden: Bool = false
    @State private var showDeleteError = false
    
    private let accountsService = BankAccountsService()
    private let transactionService = TransactionsService()
    
    private let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
                        Text("баланс, всего")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        SpoilerView(isHidden: isBalanceHidden) {
                            Text(formatAmount(totalBalance) + " ₽")
                                .font(.system(size: UIConstants.Sizes.totalAmountFontSize, weight: .bold, design: .rounded))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom)
                    ScrollView {
                        LazyVStack(spacing: .zero) {
                            if !accounts.isEmpty { Divider().padding(.horizontal) }
                            ForEach(accounts, id: \.id) { account in
                                BankAccountRow(account: account, formatter: formatter)
                                    .onTapGesture {
                                        selectedAccount = account
                                    }
                            }
                        }
                    }
                    .refreshable {
                        await loadAccounts()
                    }
                }
                .background(Color(.systemBackground))
                AddButton { showAddAccount = true }
                OfflineIndicator()
            }
            .onShake {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isBalanceHidden.toggle()
                }
            }
            .toolbar {
                CommonToolbar(
                    selectedDate: $selectedDate,
                    showDatePicker: $showDatePicker,
                    showSettings: $showSettings
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddAccount) {
                CreateAccountView { newAccount in
                    Task {
                        _ = await accountsService.createAccount(newAccount)
                        await loadAccounts()
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
                .presentationDetents([.medium])
            }
            .sheet(item: $selectedAccount) { account in
                BalanceAdjustmentView(
                    account: account,
                    appCurrency: "Руб.",
                    formatter: formatter,
                    onSave: { newAmount, newDate in
                        adjustBalance(for: account, newAmount: newAmount, newDate: newDate)
                    },
                    onDelete: { id in
                        deleteAccount(id: id)
                    }
                )
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .analytics:
                    AnalyticsView()
                }
            }
            .onAppear {
                Task { await loadAccounts() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionsDidChange)) { _ in
                Task { await loadAccounts() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .accountsDidChange)) { _ in
                Task { await loadAccounts() }
            }
            .alert("Нельзя удалить счёт", isPresented: $showDeleteError) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text("Сначала удалите все операции по этому счёту")
            }
        }
    }
    
    private func loadAccounts() async {
        let all = await accountsService.fetchAccounts()
        await MainActor.run {
            accounts = all
            totalBalance = all.reduce(Decimal.zero) { $0 + $1.balance }
        }
    }
    
    private func formatAmount(_ value: Decimal) -> String {
        let number = value as NSDecimalNumber
        return formatter.string(from: number) ?? "0"
    }
    
    private func adjustBalance(for account: BankAccount, newAmount: Decimal, newDate: Date) {
        Task {
            let updated = BankAccount(
                id: account.id,
                userId: account.userId,
                name: account.name,
                emoji: account.emoji,
                balance: newAmount,
                currency: account.currency,
                createdAt: account.createdAt,
                updatedAt: ISO8601DateFormatter().string(from: newDate)
            )
            _ = await accountsService.updateAccount(updated)
            await loadAccounts()
            await MainActor.run {
                selectedAccount = nil
            }
        }
    }
    
    private func deleteAccount(id: Int) {
        Task {
            let transactions = await transactionService.fetchTransactionsForAccount(id: id)
            
            await MainActor.run {
                if transactions.isEmpty {
                    Task {
                        await accountsService.deleteAccount(id: id)
                        await loadAccounts()
                        selectedAccount = nil
                    }
                } else {
                    showDeleteError = true
                    selectedAccount = nil
                }
            }
        }
    }
}
