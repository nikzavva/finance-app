import SwiftUI

struct AccountSelectionView: View {
    let onSelect: (BankAccount) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var accounts: [BankAccount] = []
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    private let accountsService = BankAccountsService()
    
    private var filteredAccounts: [BankAccount] {
        guard !searchText.isEmpty else { return accounts }
        let words = searchText.lowercased().split(separator: " ").map(String.init)
        return accounts.filter { account in
            let name = account.name.lowercased()
            return words.allSatisfy { name.contains($0) }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    LazyVStack(spacing: .zero) {
                        Divider()
                            .padding(.horizontal)
                        ForEach(filteredAccounts, id: \.id) { account in
                            Button {
                                onSelect(account)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(String(account.emoji))
                                        .font(.title2)
                                    Text(account.name)
                                        .font(.body)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .contentShape(Rectangle())
                .onTapGesture {
                    isSearchFocused = false
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: ""
            )
            .focused($isSearchFocused)
            .navigationTitle("Счета")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
            }
            .onAppear {
                Task {
                    let all = await accountsService.fetchAccounts()
                    await MainActor.run {
                        accounts = all
                    }
                }
            }
        }
    }
}
