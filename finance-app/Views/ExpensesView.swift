import SwiftUI

struct ExpensesView: View {
    var body: some View {
        TransactionsListView(direction: .outcome)
    }
}
