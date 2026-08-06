import Combine
import Foundation

@MainActor
final class AccountSelectionViewModel: ObservableObject {
    @Published private(set) var accounts: [BankAccount] = []
    @Published var searchText = ""

    private let accountsService: any BankAccountsServicing
    private var loadRequestID = UUID()

    init(accountsService: (any BankAccountsServicing)? = nil) {
        self.accountsService = accountsService ?? BankAccountsService()
    }

    var filteredAccounts: [BankAccount] {
        guard !searchText.isEmpty else { return accounts }
        let words = searchText.lowercased().split(separator: " ").map(String.init)
        return accounts.filter { account in
            let name = account.name.lowercased()
            return words.allSatisfy { name.contains($0) }
        }
    }

    func loadAccounts() async {
        let requestID = UUID()
        loadRequestID = requestID
        let loadedAccounts = await accountsService.fetchAccounts()
        guard loadRequestID == requestID else { return }
        accounts = loadedAccounts
    }
}
