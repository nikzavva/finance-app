import SwiftUI

struct TransactionsListView: View {
    @EnvironmentObject private var settings: AppSettings
    @Binding private var selectedDate: Date
    @Binding private var selectedCategory: Category?
    @StateObject private var viewModel: TransactionsListViewModel

    init(
        direction: Direction,
        selectedDate: Binding<Date>,
        selectedCategory: Binding<Category?>
    ) {
        _selectedDate = selectedDate
        _selectedCategory = selectedCategory
        _viewModel = StateObject(wrappedValue: TransactionsListViewModel(direction: direction))
    }

    var body: some View {
        ZStack {
            mainContent
            AddButton { viewModel.showCreateForm() }
            OfflineIndicator()
        }
        .sheet(isPresented: $viewModel.showCreateTransaction) {
            CreateTransactionView(
                direction: viewModel.direction,
                initialAccount: nil
            )
        }
        .sheet(item: $viewModel.selectedTransaction) { transaction in
            EditTransactionView(transaction: transaction)
        }
        .onAppear {
            viewModel.onAppear(
                selectedDate: selectedDate,
                selectedCategory: selectedCategory,
                currency: settings.currency
            )
        }
        .onChange(of: settings.currency) { _, currency in
            viewModel.setCurrency(currency)
        }
        .onChange(of: selectedDate) {
            viewModel.loadTransactions(
                selectedDate: selectedDate,
                selectedCategory: selectedCategory
            )
        }
        .onChange(of: viewModel.sortOrder) {
            viewModel.loadTransactions(
                selectedDate: selectedDate,
                selectedCategory: selectedCategory
            )
        }
        .onChange(of: selectedCategory) {
            viewModel.loadTransactions(
                selectedDate: selectedDate,
                selectedCategory: selectedCategory
            )
        }
        .onDisappear {
            viewModel.cancelLoading()
        }
        .networkLoadingOverlay()
    }

    private var mainContent: some View {
        VStack {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
                Text(
                    (viewModel.direction == .income ? "доходы, всего" : "расходы, всего")
                        .appLocalized(for: settings.language)
                )
                    .font(.callout)
                    .foregroundColor(.secondary)
                Text(viewModel.formattedTotalAmount(currencySymbol: settings.currency.symbol))
                    .font(.system(size: UIConstants.Sizes.totalAmountFontSize, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom)

            Picker("Сортировка", selection: $viewModel.sortOrder) {
                Text("По дате").tag(SortOrder.date)
                Text("По сумме").tag(SortOrder.amount)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            ScrollView {
                LazyVStack(spacing: .zero) {
                    ForEach(viewModel.transactions, id: \.id) { transaction in
                        TransactionRow(
                            category: viewModel.category(for: transaction),
                            transaction: transaction,
                            formatter: viewModel.formatter,
                            currencySymbol: settings.currency.symbol
                        )
                        .onTapGesture {
                            viewModel.selectTransaction(transaction)
                        }
                    }
                }
            }
            .refreshable {
                selectedCategory = nil
                viewModel.loadTransactions(
                    selectedDate: selectedDate,
                    selectedCategory: nil
                )
            }
        }
        .background(Color(.systemBackground))
    }
}
