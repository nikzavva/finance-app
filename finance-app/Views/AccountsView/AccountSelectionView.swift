import SwiftUI

struct AccountSelectionView: View {
    let onSelect: (BankAccount) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var state: LoadingState<[BankAccount]> = .idle
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    private let accountsService = BankAccountsService()
    
    private var filteredAccounts: [BankAccount] {
        guard case .loaded(let accounts) = state else { return [] }
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
                content
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
                loadAccounts()
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            Color.clear
                .onAppear { loadAccounts() }
        case .loading:
            ProgressView("Загрузка...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
        case .loaded:
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
                                Text(account.emoji)
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
        case .error(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text(message)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Повторить") {
                    loadAccounts()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
    }
    
    private func loadAccounts() {
        state = .loading
        Task {
            do {
                let all = try await accountsService.fetchAccounts()
                await MainActor.run {
                    state = .loaded(all)
                }
            } catch {
                await MainActor.run {
                    state = .error(error.localizedDescription)
                }
            }
        }
    }
}
