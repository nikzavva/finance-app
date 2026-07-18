import SwiftUI

struct BankAccountRow: View {
    let account: BankAccount
    let formatter: NumberFormatter
    
    var body: some View {
        VStack(spacing: .zero) {
            HStack {
                Text(account.emoji)
                    .font(.title2)
                    .frame(width: UIConstants.Sizes.categoryIcon, height: UIConstants.Sizes.categoryIcon)
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
            
            Divider()
                .padding(.horizontal)
        }
    }
}
