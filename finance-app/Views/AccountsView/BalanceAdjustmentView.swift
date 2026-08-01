import SwiftUI

struct BalanceAdjustmentView: View {
    let account: BankAccount
    let appCurrency: String
    let formatter: NumberFormatter
    let onSave: (Decimal, Date) -> Void
    let onDelete: (Int) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var amount: String = ""
    @State private var previousAmount: String = ""
    @State private var date: Date = Date()
    @State private var showDeleteConfirmation = false
    @FocusState private var isAmountFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: .zero) {
                AmountTextField(
                    amount: $amount,
                    previousAmount: $previousAmount,
                    isFocused: $isAmountFocused,
                    maxAmount: Constants.maxAmountBankAccount
                )
                
                HStack {
                    Text("Дата и время")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(date.formatted(date: .abbreviated, time: .shortened))
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
                    Text(appCurrency)
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
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        guard let decimalAmount = AmountTextField.parseAmount(amount) else { return }
                        onSave(decimalAmount, date)
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.body)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .onAppear {
                let initial = AmountTextField.formatAmount(account.balance, formatter: formatter)
                amount = initial
                previousAmount = initial
            }
            .alert("Удалить счёт?", isPresented: $showDeleteConfirmation) {
                Button("Удалить", role: .destructive) {
                    onDelete(account.id)
                    dismiss()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Счёт будет удалён. Это действие нельзя отменить")
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
