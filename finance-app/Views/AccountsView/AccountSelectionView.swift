import SwiftUI

struct AccountSelectionView: View {
    let onSelect: (BankAccount) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AccountSelectionViewModel()
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    LazyVStack(spacing: .zero) {
                        Divider()
                            .padding(.horizontal)
                        ForEach(viewModel.filteredAccounts, id: \.id) { account in
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
                text: $viewModel.searchText,
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
            .task {
                await viewModel.loadAccounts()
            }
        }
        .networkLoadingOverlay()
    }
}
