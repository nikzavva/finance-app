import SwiftUI

struct CategorySelectionView: View {
    let onSelect: (Category) -> Void
    let dismissesOnSelection: Bool
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel: CategorySelectionViewModel
    @State private var selectedCategoryID: Int?
    @FocusState private var isSearchFocused: Bool

    init(
        direction: Direction,
        selectedCategoryID: Int? = nil,
        dismissesOnSelection: Bool = true,
        onSelect: @escaping (Category) -> Void
    ) {
        self.onSelect = onSelect
        self.dismissesOnSelection = dismissesOnSelection
        _selectedCategoryID = State(initialValue: selectedCategoryID)
        _viewModel = StateObject(
            wrappedValue: CategorySelectionViewModel(
                direction: direction
            )
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    LazyVStack(spacing: .zero) {
                        Divider()
                            .padding(.horizontal)
                        ForEach(viewModel.filteredCategories, id: \.id) { category in
                            Button {
                                selectedCategoryID = selectedCategoryID == category.id
                                    ? nil
                                    : category.id
                                onSelect(category)
                                if dismissesOnSelection {
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Text(String(category.emoji))
                                        .font(.title2)
                                    Text(category.localizedName(for: settings.language))
                                        .font(.body)
                                    Spacer()
                                    if selectedCategoryID == category.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
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
            .navigationTitle("Статьи")
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
                await viewModel.load()
            }
        }
        .networkLoadingOverlay()
    }
}
