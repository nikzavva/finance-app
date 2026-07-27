import SwiftUI

struct BankAccountRow: View {
    let account: BankAccount
    let formatter: NumberFormatter
    
    var body: some View {
        VStack(spacing: .zero) {
            HStack {
                Text(account.emoji)
                    .font(.title2)
                    .frame(width: UIConstants.Sizes.icon, height: UIConstants.Sizes.icon)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemGray4))
                    )
                
                Text(account.name)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                let amount = account.balance as NSDecimalNumber
                Text((formatter.string(from: amount) ?? "0") + " ₽")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)
            .padding(.vertical)
            .contentShape(Rectangle())
            
            Divider()
                .padding(.horizontal)
        }
    }
}
