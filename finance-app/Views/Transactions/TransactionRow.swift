import SwiftUI

struct TransactionRow: View {
    let category: Category?
    let transaction: Transaction
    let formatter: NumberFormatter

    var body: some View {
        VStack(spacing: .zero) {
            HStack {
                Text(String(category?.emoji ?? "💳"))
                    .font(.title2)
                    .frame(width: UIConstants.Sizes.categoryIcon, height: UIConstants.Sizes.categoryIcon)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemGray4))
                    )

                Text(transaction.comment ?? "Без описания")
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                let amount = transaction.amount as NSDecimalNumber
                Text((formatter.string(from: amount) ?? "0") + " ₽")
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
