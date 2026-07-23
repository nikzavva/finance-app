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
    
    private let maxAmount: Decimal = 9_999_999
    
    var body: some View {
        NavigationStack {
            VStack(spacing: .zero) {
                TextField("", text: $amount)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .font(.system(size: UIConstants.Sizes.totalAmountFontSize, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top)
                    .padding(.bottom)
                    .onChange(of: amount) { _, newValue in
                        formatInput(newValue)
                    }
                
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color(.systemGray3))
                        .frame(width: geometry.size.width * 2/3, height: 1)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 1)
                .padding(.bottom)
                
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
                        guard let decimalAmount = parseAmount(amount) else { return }
                        onSave(decimalAmount, date)
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.body)
                            .foregroundColor(parseAmount(amount) == nil ? .gray : .accentColor)
                    }
                    .disabled(parseAmount(amount) == nil)
                }
            }
            .onAppear {
                let initial = formatAmount(account.balance)
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
    
    private func formatAmount(_ value: Decimal) -> String {
        let number = value as NSDecimalNumber
        return formatter.string(from: number) ?? "0"
    }
    
    private func parseAmount(_ string: String) -> Decimal? {
        let cleaned = string.replacingOccurrences(of: " ", with: "")
                          .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleaned)
    }
    
    private func formatInput(_ input: String) {
        let filtered = input.replacingOccurrences(
            of: "[^\\d\\s,.]",
            with: "",
            options: .regularExpression
        )
        
        let cleaned = filtered.replacingOccurrences(of: " ", with: "")
                              .replacingOccurrences(of: ",", with: ".")
        
        if cleaned.isEmpty {
            amount = "0"
            previousAmount = "0"
            return
        }
        
        guard let decimal = Decimal(string: cleaned) else {
            return
        }
        
        if decimal > maxAmount {
            amount = previousAmount
            return
        }
        
        let formatted = formatAmount(decimal)
        amount = formatted
        previousAmount = formatted
    }
}
