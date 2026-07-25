import SwiftUI

struct BankAccountsView: View {
    @Binding var selectedDate: Date
    
    @State private var state: LoadingState<[BankAccount]> = .idle
    @State private var showDatePicker = false
    @State private var showSettings = false
    @State private var showAddAccount = false
    @State private var selectedAccount: BankAccount?
    @State private var isBalanceHidden: Bool = false
    @State private var showOperationError = false
    @State private var operationErrorMessage = ""
    
    private let accountsService = BankAccountsService()
    
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
                content
                AddButton { showAddAccount = true }
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
                    createAccount(newAccount)
                }
            }
            .sheet(isPresented: $showSettings) {
                Text("Настройки (заглушка)")
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
            .alert("Ошибка", isPresented: $showOperationError) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(operationErrorMessage)
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            Color.clear.onAppear { loadAccounts() }
        case .loading:
            VStack {
                header(totalBalance: 0)
                ProgressView("Загрузка...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(.systemBackground))
        case .loaded(let accounts):
            VStack {
                header(totalBalance: accounts.reduce(Decimal.zero) { $0 + $1.balance })
                accountsList(accounts)
            }
            .background(Color(.systemBackground))
        case .error(let message):
            VStack {
                header(totalBalance: 0)
                errorView(message)
            }
            .background(Color(.systemBackground))
        }
    }
    
    private func header(totalBalance: Decimal) -> some View {
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
    }
    
    private func accountsList(_ accounts: [BankAccount]) -> some View {
        ScrollView {
            LazyVStack(spacing: .zero) {
                Divider()
                    .padding(.horizontal)
                ForEach(accounts, id: \.id) { account in
                    BankAccountRow(account: account, formatter: formatter)
                        .onTapGesture {
                            selectedAccount = account
                        }
                }
            }
        }
        .refreshable {
            loadAccounts()
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Повторить") {
                loadAccounts()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadAccounts() {
        state = .loading
        Task {
            do {
                let accounts = try await accountsService.fetchAccounts()
                await MainActor.run {
                    state = .loaded(accounts)
                }
            } catch {
                await MainActor.run {
                    state = .error(error.localizedDescription)
                }
            }
        }
    }
    
    private func createAccount(_ account: BankAccount) {
        state = .loading
        Task {
            do {
                _ = try await accountsService.createAccount(account)
                let accounts = try await accountsService.fetchAccounts()
                await MainActor.run {
                    state = .loaded(accounts)
                }
            } catch {
                await MainActor.run {
                    operationErrorMessage = "Не удалось создать счёт: \(error.localizedDescription)"
                    showOperationError = true
                    loadAccounts()
                }
            }
        }
    }
    
    private func adjustBalance(for account: BankAccount, newAmount: Decimal, newDate: Date) {
        state = .loading
        Task {
            do {
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
                _ = try await accountsService.updateAccount(updated)
                let accounts = try await accountsService.fetchAccounts()
                await MainActor.run {
                    state = .loaded(accounts)
                    selectedAccount = nil
                }
            } catch {
                await MainActor.run {
                    operationErrorMessage = "Не удалось обновить баланс: \(error.localizedDescription)"
                    showOperationError = true
                    loadAccounts()
                }
            }
        }
    }
    
    private func deleteAccount(id: Int) {
        state = .loading
        Task {
            do {
                try await accountsService.deleteAccount(id: id)
                let accounts = try await accountsService.fetchAccounts()
                await MainActor.run {
                    state = .loaded(accounts)
                    selectedAccount = nil
                }
            } catch {
                await MainActor.run {
                    operationErrorMessage = "Не удалось удалить счёт: \(error.localizedDescription)"
                    showOperationError = true
                    loadAccounts()
                }
            }
        }
    }
    
    private func formatAmount(_ value: Decimal) -> String {
        let number = value as NSDecimalNumber
        return formatter.string(from: number) ?? "0"
    }
}
