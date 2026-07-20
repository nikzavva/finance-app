import SwiftUI

struct TransactionsListView: View {
    let direction: Direction
    @Binding var selectedDate: Date

    @State private var transactions: [Transaction] = []
    @State private var totalAmount: Decimal = 0
    @State private var showDatePicker = false
    @State private var showSettings = false
    @State private var showAddTransaction = false
    @State private var categories: [Category] = []
    @State private var sortOrder: SortOrder = .date
    @State private var selectedCategory: Category?

    private let transactionService = TransactionsService()
    private let categoriesService = CategoriesService()
    private let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                mainContent
                AddButton { showAddTransaction = true }
            }
            .toolbar {
                CommonToolbar(
                    selectedDate: $selectedDate,
                    showDatePicker: $showDatePicker,
                    showSettings: $showSettings
                )
            }
            .sheet(isPresented: $showAddTransaction) {
                Text("Добавление операции (заглушка)")
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
            .onAppear {
                selectedCategory = nil
                loadCategories()
                loadTransactions()
            }
            .onChange(of: selectedDate) {
                loadTransactions()
            }
            .onChange(of: sortOrder) {
                loadTransactions()
            }
            .onChange(of: selectedCategory) {
                loadTransactions()
            }
        }
    }

    private var mainContent: some View {
        VStack {
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

            Picker("Сортировка", selection: $sortOrder) {
                Text("По дате").tag(SortOrder.date)
                Text("По сумме").tag(SortOrder.amount)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            ScrollView {
                LazyVStack(spacing: .zero) {
                    ForEach(transactions, id: \.id) { transaction in
                        TransactionRow(
                            category: categories.first(where: { $0.id == transaction.categoryId }),
                            transaction: transaction,
                            formatter: formatter
                        )
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }

    private func loadCategories() {
        Task {
            let all = await categoriesService.fetchAllCategories()
            await MainActor.run {
                categories = all
            }
        }
    }

    private func loadTransactions() {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        Task {
            let all = await transactionService.fetchTransactions(from: startOfDay, to: endOfDay)
            let filtered = all.filter { transaction in
                transaction.direction == direction &&
                (selectedCategory == nil || transaction.categoryId == selectedCategory?.id)
            }

            let sorted: [Transaction]
            switch sortOrder {
            case .date:
                sorted = filtered.sorted(by: { $0.transactionDate > $1.transactionDate })
            case .amount:
                sorted = filtered.sorted(by: { $0.amount > $1.amount })
            }

            await MainActor.run {
                transactions = sorted
                totalAmount = filtered.reduce(0) { $0 + $1.amount }
            }
        }
    }

    private func formatAmount(_ value: Decimal) -> String {
        let number = value as NSDecimalNumber
        return formatter.string(from: number) ?? "0"
    }
}
