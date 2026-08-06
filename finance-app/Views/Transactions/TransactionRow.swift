import SwiftUI

struct TransactionRow: View {
    let category: Category?
    let transaction: Transaction
    let formatter: NumberFormatter
    let currencySymbol: String

    var body: some View {
        VStack(spacing: .zero) {
            HStack {
                Text(String(category?.emoji ?? "💳"))
                    .font(.title2)
                    .frame(width: UIConstants.Sizes.icon, height: UIConstants.Sizes.icon)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemGray4))
                    )

                Text(transaction.comment ?? "Без описания".appLocalized)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                let amount = transaction.amount as NSDecimalNumber
                Text((formatter.string(from: amount) ?? "0") + " \(currencySymbol)")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)
            .padding(.vertical)

            Divider()
                .padding(.horizontal)
        }
        .contentShape(Rectangle())
    }
}
