import SwiftUI

struct BalanceAdjustmentView: View {
    let account: BankAccount
    let appCurrency: String
    let formatter: NumberFormatter
    let onSave: (Decimal, Date) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var amount: String = ""
    @State private var previousAmount: String = ""
    @State private var date: Date = Date()
    @FocusState private var isAmountFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: .zero) {
                AmountTextField(
                    amount: $amount,
                    previousAmount: $previousAmount,
                    isFocused: $isAmountFocused
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
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundColor(.primary)
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
                            .foregroundColor(AmountTextField.parseAmount(amount) == nil ? .gray : .accentColor)
                    }
                    .disabled(AmountTextField.parseAmount(amount) == nil)
                }
            }
            .onAppear {
                let initial = AmountTextField.formatAmount(account.balance, formatter: formatter)
                amount = initial
                previousAmount = initial
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
