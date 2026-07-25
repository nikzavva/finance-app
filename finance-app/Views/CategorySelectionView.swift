import SwiftUI

struct CategorySelectionView: View {
    let direction: Direction
    let onSelect: (Category) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var categories: [Category] = []
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    private let categoriesService = CategoriesService()
    
    private var filteredCategories: [Category] {
        guard !searchText.isEmpty else { return categories }
        let words = searchText.lowercased().split(separator: " ").map(String.init)
        return categories.filter { category in
            let name = category.name.lowercased()
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
                        ForEach(filteredCategories, id: \.id) { category in
                            Button {
                                onSelect(category)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(String(category.emoji))
                                        .font(.title2)
                                    Text(category.name)
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
            .onAppear {
                loadCategories()
            }
        }
    }
    
    private func loadCategories() {
        Task {
            let all = await categoriesService.fetchCategories(direction: direction)
            await MainActor.run {
                categories = all
            }
        }
    }
}
