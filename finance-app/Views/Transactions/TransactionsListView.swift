import SwiftUI

struct TransactionsListView: View {
    let direction: Direction

    @State private var selectedDate: Date = Date()
    @State private var transactions: [Transaction] = []
    @State private var totalAmount: Decimal = 0
    @State private var showDatePicker = false
    @State private var showSettings = false
    @State private var showAddTransaction = false
    @State private var categories: [Category] = []
    @State private var sortOrder: SortOrder = .date

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
                addButton
            }
            .toolbar { toolbarItems }
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
                Text("Настройки (заглушка)")
            }
            .onAppear {
                loadCategories()
                loadTransactions()
            }
            .onChange(of: selectedDate) {
                loadTransactions()
            }
            .onChange(of: sortOrder) {
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

    private var addButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: { showAddTransaction = true }) {
                    Image(systemName: "plus")
                        .font(.largeTitle)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(width: UIConstants.Sizes.addButton, height: UIConstants.Sizes.addButton)
                        .background(Color("AccentColor"))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing)
                .padding(.bottom)
            }
        }
    }

    private var toolbarItems: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showDatePicker = true }) {
                    HStack {
                        Image(systemName: "calendar")
                        Text(selectedDate, format: .dateTime.day().month(.wide))
                    }
                    .font(.callout)
                    .foregroundColor(.primary)
                }
                .popover(isPresented: $showDatePicker, attachmentAnchor: .point(.bottom)) {
                    datePicker
                        .presentationCompactAdaptation(.none)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(value: AppRoute.analytics) {
                    Image(systemName: "chart.pie")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }
            
            if #available(iOS 26, *) {
                ToolbarSpacer(.fixed, placement: .navigationBarTrailing)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
        }
    }

    private var datePicker: some View {
        DatePicker("Выберите дату", selection: $selectedDate, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .frame(minWidth: UIConstants.Sizes.datePickerMinWidth)
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
            let filtered = all.filter { $0.direction == direction }

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
