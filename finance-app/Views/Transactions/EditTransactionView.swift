import SwiftUI

struct EditTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel: EditTransactionViewModel
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isCommentFocused: Bool

    init(transaction: Transaction) {
        _viewModel = StateObject(
            wrappedValue: EditTransactionViewModel(
                transaction: transaction
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
                    Button {
                        viewModel.requestDeletion()
                    } label: {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundColor(.red)
                    }
                    .disabled(viewModel.isSaving)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            if await viewModel.submit() {
                                HapticsManager.shared.play(.confirmation)
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
                CategorySelectionView(direction: viewModel.transaction.direction) { category in
                    viewModel.selectCategory(category)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $viewModel.showAccountSelection) {
                AccountSelectionView(currency: viewModel.accountCurrency) { account in
                    viewModel.selectAccount(account)
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Удалить операцию?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Удалить", role: .destructive) {
                    Task {
                        if await viewModel.delete() {
                            dismiss()
                        }
                    }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Это действие нельзя отменить")
            }
            .alert(viewModel.validationTitle, isPresented: $viewModel.showValidationError) {
                Button("ОК", role: .cancel) {
                    viewModel.dismissValidationError()
                }
            } message: {
                Text(viewModel.validationMessage)
            }
            .alert("Ошибка сохранения", isPresented: $viewModel.showSaveError) {
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
