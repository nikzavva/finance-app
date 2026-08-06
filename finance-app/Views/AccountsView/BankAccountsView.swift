import SwiftUI

struct BankAccountsView: View {
    @StateObject private var viewModel = BankAccountsViewModel()
    
    var body: some View {
        ZStack {
            VStack {
                VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
                    Text("баланс, всего")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    SpoilerView(isHidden: viewModel.isBalanceHidden) {
                        Text(viewModel.formattedTotalBalance + " ₽")
                            .font(.system(size: UIConstants.Sizes.totalAmountFontSize, weight: .bold, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom)
                ScrollView {
                    LazyVStack(spacing: .zero) {
                        if !viewModel.accounts.isEmpty { Divider().padding(.horizontal) }
                        ForEach(viewModel.accounts, id: \.id) { account in
                            BankAccountRow(account: account, formatter: viewModel.formatter)
                                .onTapGesture {
                                    viewModel.selectedAccount = account
                                }
                        }
                    }
                }
                .refreshable {
                    await viewModel.loadAccounts()
                }
            }
            .background(Color(.systemBackground))
            AddButton { viewModel.showAddAccount = true }
            OfflineIndicator()
        }
        .onShake {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.isBalanceHidden.toggle()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showAddAccount) {
            CreateAccountView { newAccount in
                Task {
                    await viewModel.createAccount(newAccount)
                }
            }
        }
        .sheet(item: $viewModel.selectedAccount) { account in
            BalanceAdjustmentView(
                account: account,
                appCurrency: "Руб.",
                formatter: viewModel.formatter,
                onSave: { newAmount, newDate in
                    Task {
                        await viewModel.adjustBalance(
                            for: account,
                            newAmount: newAmount,
                            newDate: newDate
                        )
                    }
                },
                onDelete: { id in
                    Task {
                        await viewModel.deleteAccount(id: id)
                    }
                }
            )
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .alert("Не удалось удалить счёт", isPresented: $viewModel.showDeleteError) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(viewModel.deleteErrorMessage)
        }
        .networkLoadingOverlay()
    }
}
