import SwiftUI

struct CreateTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel: CreateTransactionViewModel
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isCommentFocused: Bool

    init(
        direction: Direction,
        initialAccount: BankAccount?
    ) {
        _viewModel = StateObject(
            wrappedValue: CreateTransactionViewModel(
                direction: direction,
                initialAccount: initialAccount
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: .zero) {
                AmountTextField(
                    amount: $viewModel.amount,
                    previousAmount: $viewModel.previousAmount,
                    isFocused: $isAmountFocused
                )

                Button {
                    viewModel.openCategorySelection()
                } label: {
                    HStack {
                        Text("Статья")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(
                            viewModel.selectedCategory?.localizedName(for: settings.language)
                                ?? "Выбрать".appLocalized(for: settings.language)
                        )
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.horizontal)

                HStack {
                    Text("Дата и время")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    DatePicker(
                        "",
                        selection: $viewModel.date,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                }
                .padding(.horizontal)
                .padding(.vertical)

                Divider()
                    .padding(.horizontal)

                Button {
                    viewModel.openAccountSelection()
                } label: {
                    HStack {
                        Text("Счёт")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(viewModel.selectedAccount?.name ?? "Выбрать".appLocalized)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.horizontal)

                HStack {
                    Text("Комментарий")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    TextField(
                        "",
                        text: $viewModel.comment,
                        prompt: Text("Комментарий").foregroundColor(.secondary)
                    )
                    .multilineTextAlignment(.trailing)
                    .focused($isCommentFocused)
                    .font(.body)
                }
                .padding(.horizontal)
                .padding(.vertical)

                Divider()
                    .padding(.horizontal)

                Spacer()
            }
            .background(Color(.systemBackground))
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            if await viewModel.submit() {
                                dismiss()
                            }
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.body)
                            .foregroundColor(.accentColor)
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .task {
                await viewModel.loadInitialData()
            }
            .sheet(isPresented: $viewModel.showCategorySelection) {
                CategorySelectionView(direction: viewModel.direction) { category in
                    viewModel.selectCategory(category)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $viewModel.showAccountSelection) {
                AccountSelectionView(currency: viewModel.currency) { account in
                    viewModel.selectAccount(account)
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Ошибка создания данных", isPresented: $viewModel.showValidationError) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(viewModel.validationMessage)
            }
            .alert("Ошибка загрузки", isPresented: $viewModel.showLoadError) {
                Button("ОК", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Ошибка создания данных", isPresented: $viewModel.showSaveError) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .gesture(
                DragGesture()
                    .onEnded { _ in
                        isAmountFocused = false
                        isCommentFocused = false
                    }
            )
        }
        .presentationDetents([.medium])
    }
}
