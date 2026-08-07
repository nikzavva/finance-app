import SwiftUI

struct BalanceAdjustmentView: View {
    let appCurrency: String
    let onSave: (Decimal, Date) -> Void
    let onDelete: (Int) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel: BalanceAdjustmentViewModel
    @FocusState private var isAmountFocused: Bool

    init(
        account: BankAccount,
        appCurrency: String,
        formatter: NumberFormatter,
        onSave: @escaping (Decimal, Date) -> Void,
        onDelete: @escaping (Int) -> Void
    ) {
        self.appCurrency = appCurrency
        self.onSave = onSave
        self.onDelete = onDelete
        _viewModel = StateObject(
            wrappedValue: BalanceAdjustmentViewModel(account: account, formatter: formatter)
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: .zero) {
                AmountTextField(
                    amount: $viewModel.amount,
                    previousAmount: $viewModel.previousAmount,
                    isFocused: $isAmountFocused,
                    maxAmount: Constants.maxAmountBankAccount
                )
                
                HStack {
                    Text("Дата и время")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(viewModel.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical)
                
                Divider()
                    .padding(.horizontal)
                
                HStack {
                    Text("Валюта")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(AppCurrency(rawValue: appCurrency)?.title(for: settings.language) ?? appCurrency)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical)
                
                Divider()
                    .padding(.horizontal)
                
                Spacer()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Корректировка баланса")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewModel.requestDeletion()
                    } label: {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundColor(.red)
                    }
                    .disabled(viewModel.isSubmitting)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        guard let submission = viewModel.submitBalance() else { return }
                        onSave(submission.amount, submission.date)
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.body)
                            .foregroundColor(.accentColor)
                    }
                    .disabled(viewModel.isSubmitting)
                }
            }
            .alert("Удалить счёт?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Удалить", role: .destructive) {
                    guard let accountID = viewModel.confirmDeletion() else { return }
                    onDelete(accountID)
                    dismiss()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Счёт и все операции по нему будут удалены. Это действие нельзя отменить")
            }
            .gesture(
                DragGesture()
                    .onEnded { _ in
                        isAmountFocused = false
                    }
            )
        }
        .presentationDetents([.medium])
    }
}
