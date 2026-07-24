import SwiftUI

struct AmountTextField: View {
    @Binding var amount: String
    @Binding var previousAmount: String
    @FocusState.Binding var isFocused: Bool
    
    private let decimalSeparator = Locale.current.decimalSeparator ?? ","
    
    private let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.decimalSeparator = Locale.current.decimalSeparator ?? ","
        return f
    }()
    
    var body: some View {
        VStack(spacing: .zero) {
            TextField("", text: $amount)
                .keyboardType(.decimalPad)
                .focused($isFocused)
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
                    .frame(width: geometry.size.width * 3/4, height: 1)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 1)
            .padding(.bottom)
        }
    }
    
    private func formatInput(_ input: String) {
        var filtered = ""
        var hasSeparator = false
        
        for char in input {
            if char.isNumber {
                filtered.append(char)
            } else if (char == "," || char == ".") && !hasSeparator {
                filtered.append(decimalSeparator)
                hasSeparator = true
            }
        }
        
        if filtered.isEmpty {
            amount = "0"
            previousAmount = "0"
            return
        }
        
        let cleaned = filtered.replacingOccurrences(of: decimalSeparator, with: ".")
        let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        
        if let integerPart = Decimal(string: String(parts[0])),
           integerPart > Constants.maxAmount {
            amount = previousAmount
            return
        }
        
        if parts.count == 2 && parts[1].isEmpty {
            let integerFormatted = formatAmount(Decimal(string: String(parts[0])) ?? 0)
            amount = integerFormatted + decimalSeparator
            return
        }
        
        if parts.count == 2 {
            let fractionalPart = String(parts[1])
            
            if fractionalPart.count > 2 {
                amount = previousAmount
                return
            }
            
            let integerFormatted = formatAmount(Decimal(string: String(parts[0])) ?? 0)
            amount = integerFormatted + decimalSeparator + fractionalPart
            previousAmount = amount
            return
        }
        
        guard let decimal = Decimal(string: cleaned) else {
            amount = previousAmount
            return
        }
        
        let formatted = formatAmount(decimal)
        amount = formatted
        previousAmount = formatted
    }
    
    private func formatAmount(_ value: Decimal) -> String {
        let number = value as NSDecimalNumber
        return formatter.string(from: number) ?? "0"
    }
    
    static func parseAmount(_ string: String) -> Decimal? {
        let separator = Locale.current.decimalSeparator ?? ","
        let cleaned = string.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: separator, with: ".")
        return Decimal(string: cleaned)
    }
    
    static func formatAmount(_ value: Decimal, formatter: NumberFormatter) -> String {
        let number = value as NSDecimalNumber
        return formatter.string(from: number) ?? "0"
    }
}
