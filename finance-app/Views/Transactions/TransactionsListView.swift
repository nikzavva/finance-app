import SwiftUI

struct TransactionsListView: View {
    let direction: Direction
    @Binding var selectedDate: Date
    
    @State private var state: LoadingState<[Transaction]> = .idle
    @State private var categories: [Category] = []
    @State private var totalAmount: Decimal = 0
    @State private var sortOrder: SortOrder = .date
    @State private var showDatePicker = false
    @State private var showSettings = false
    @State private var showCreateTransaction = false
    @State private var selectedCategory: Category?
    @State private var selectedTransaction: Transaction?
    @State private var showOperationError = false
    @State private var operationErrorMessage = ""
    
    private let transactionService = TransactionsService()
    private let categoriesService = CategoriesService()
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
                AddButton { showCreateTransaction = true }
            }
            .toolbar {
                CommonToolbar(
                    selectedDate: $selectedDate,
                    showDatePicker: $showDatePicker,
                    showSettings: $showSettings
                )
            }
            .sheet(isPresented: $showCreateTransaction) {
                CreateTransactionView(
                    direction: direction,
                    initialAccount: nil,
                    onCreate: { newTransaction in
                        createTransaction(newTransaction)
                    }
                )
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .analytics:
                    AnalyticsView()
                }
            }
            .sheet(isPresented: $showSettings) {
                CategorySelectionView(direction: direction) { category in
                    if selectedCategory?.id == category.id {
                        selectedCategory = nil
                    } else {
                        selectedCategory = category
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedTransaction) { transaction in
                EditTransactionView(
                    transaction: transaction,
                    onSave: { updated in
                        updateTransaction(updated)
                    },
                    onDelete: { id in
                        deleteTransaction(id: id)
                    }
                )
            }
            .onAppear {
                selectedCategory = nil
                loadCategories()
                if case .idle = state {
                    loadTransactions()
                }
            }
            .onChange(of: selectedDate) {
                loadTransactions()
            }
            .onChange(of: sortOrder) {
                if case .loaded = state {
                    resortTransactions()
                }
            }
            .onChange(of: selectedCategory) {
                loadTransactions()
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
            Color.clear.onAppear { loadTransactions() }
        case .loading:
            VStack {
                header
                picker
                ProgressView("Загрузка...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(.systemBackground))
        case .loaded(let transactions):
            VStack {
                header
                picker
                transactionsList(transactions)
            }
            .background(Color(.systemBackground))
        case .error(let message):
            VStack {
                header
                picker
                errorView(message)
            }
            .background(Color(.systemBackground))
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
            Text(direction == .income ? "доходы, всего" : "расходы, всего")
                .font(.callout)
                .foregroundColor(.secondary)
            Text(formatAmount(totalAmount) + " ₽")
                .font(.system(size: UIConstants.Sizes.totalAmountFontSize, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top)
        .padding(.bottom)
    }
    
    private var picker: some View {
        Picker("Сортировка", selection: $sortOrder) {
            Text("По дате").tag(SortOrder.date)
            Text("По сумме").tag(SortOrder.amount)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    private func transactionsList(_ transactions: [Transaction]) -> some View {
        ScrollView {
            LazyVStack(spacing: .zero) {
                ForEach(transactions, id: \.id) { transaction in
                    TransactionRow(
                        category: categories.first(where: { $0.id == transaction.categoryId }),
                        transaction: transaction,
                        formatter: formatter
                    )
                    .onTapGesture {
                        selectedTransaction = transaction
                    }
                }
            }
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
                loadTransactions()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadCategories() {
        Task {
            do {
                let all = try await categoriesService.fetchAllCategories()
                await MainActor.run {
                    categories = all
                }
            } catch {
                print("Ошибка загрузки категорий: \(error)")
            }
        }
    }
    
    private func loadTransactions() {
        state = .loading
        Task {
            do {
                let accounts = try await accountsService.fetchAccounts()
                
                guard !accounts.isEmpty else {
                    await MainActor.run {
                        state = .loaded([])
                        totalAmount = 0
                    }
                    return
                }
                
                let startOfDay = Calendar.current.startOfDay(for: selectedDate)
                let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
                
                var allTransactions: [Transaction] = []
                
                try await withThrowingTaskGroup(of: [Transaction].self) { group in
                    for account in accounts {
                        group.addTask {
                            try await transactionService.fetchTransactionsByAccount(
                                accountId: account.id,
                                from: startOfDay,
                                to: endOfDay
                            )
                        }
                    }
                    
                    for try await transactions in group {
                        allTransactions.append(contentsOf: transactions)
                    }
                }
                
                let filtered = allTransactions.filter { transaction in
                    transaction.direction == direction &&
                    (selectedCategory == nil || transaction.categoryId == selectedCategory?.id)
                }
                
                let sorted = sortTransactions(filtered)
                
                await MainActor.run {
                    self.totalAmount = filtered.reduce(0) { $0 + $1.amount }
                    self.state = .loaded(sorted)
                }
            } catch {
                await MainActor.run {
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }
    
    private func sortTransactions(_ transactions: [Transaction]) -> [Transaction] {
        switch sortOrder {
        case .date:
            return transactions.sorted(by: { $0.transactionDate > $1.transactionDate })
        case .amount:
            return transactions.sorted(by: { $0.amount > $1.amount })
        }
    }
    
    private func resortTransactions() {
        guard case .loaded(let current) = state else { return }
        let sorted = sortTransactions(current)
        state = .loaded(sorted)
    }
    
    private func createTransaction(_ transaction: Transaction) {
        Task {
            do {
                _ = try await transactionService.createTransaction(transaction)
                NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
                loadTransactions()
            } catch {
                await MainActor.run {
                    operationErrorMessage = "Не удалось создать операцию: \(error.localizedDescription)"
                    showOperationError = true
                }
            }
        }
    }

    private func updateTransaction(_ transaction: Transaction) {
        Task {
            do {
                _ = try await transactionService.updateTransaction(transaction)
                NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
                loadTransactions()
            } catch {
                await MainActor.run {
                    operationErrorMessage = "Не удалось обновить операцию: \(error.localizedDescription)"
                    showOperationError = true
                }
            }
        }
    }

    private func deleteTransaction(id: Int) {
        Task {
            do {
                try await transactionService.deleteTransaction(id: id)
                NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
                loadTransactions()
            } catch {
                await MainActor.run {
                    operationErrorMessage = "Не удалось удалить операцию: \(error.localizedDescription)"
                    showOperationError = true
                }
            }
        }
    }
    
    private func formatAmount(_ value: Decimal) -> String {
        let number = value as NSDecimalNumber
        return formatter.string(from: number) ?? "0"
    }
}
