import SwiftUI

struct EditTransactionView: View {
    let transaction: Transaction
    let onSave: (Transaction) -> Void
    let onDelete: (Int) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var amount: String = ""
    @State private var previousAmount: String = ""
    @State private var date: Date = Date()
    @State private var comment: String = ""
    @State private var selectedCategory: Category?
    @State private var selectedAccount: BankAccount?
    @State private var showCategorySelection = false
    @State private var showAccountSelection = false
    @State private var showDeleteConfirmation = false
    @State private var showValidationError = false
    @State private var showLoadError = false
    @State private var errorMessage = ""
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isCommentFocused: Bool
    
    private let categoriesService = CategoriesService()
    private let accountsService = BankAccountsService()
    @State private var categories: [Category] = []
    @State private var accounts: [BankAccount] = []
    
    private let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: .zero) {
                AmountTextField(
                    amount: $amount,
                    previousAmount: $previousAmount,
                    isFocused: $isAmountFocused
                )
                
                Button {
                    showCategorySelection = true
                } label: {
                    HStack {
                        Text("Статья")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(selectedCategory?.name ?? "Выбрать")
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
                    DatePicker("", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
                .padding(.horizontal)
                .padding(.vertical)
                
                Divider()
                    .padding(.horizontal)
                
                Button {
                    showAccountSelection = true
                } label: {
                    HStack {
                        Text("Счёт")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(selectedAccount?.name ?? "Выбрать")
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
                    TextField("", text: $comment, prompt: Text("Комментарий").foregroundColor(.secondary))
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
            .navigationTitle(transaction.direction == .income ? "Корректировка дохода" : "Корректировка расхода")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if isValid {
                            save()
                        } else {
                            showValidationError = true
                        }
                    }) {
                        Image(systemName: "checkmark")
                            .font(.body)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .onAppear {
                loadInitialData()
            }
            .sheet(isPresented: $showCategorySelection) {
                CategorySelectionView(direction: transaction.direction) { category in
                    selectedCategory = category
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showAccountSelection) {
                AccountSelectionView { account in
                    selectedAccount = account
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Удалить операцию?", isPresented: $showDeleteConfirmation) {
                Button("Удалить", role: .destructive) {
                    onDelete(transaction.id)
                    dismiss()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Это действие нельзя отменить")
            }
            .alert("Заполните сумму", isPresented: $showValidationError) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text("Сумма должна быть больше 0")
            }
            .alert("Ошибка загрузки", isPresented: $showLoadError) {
                Button("ОК", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(errorMessage)
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
    
    private var isValid: Bool {
        guard let amount = AmountTextField.parseAmount(self.amount),
              amount > 0 else { return false }
        return true
    }

    private func loadInitialData() {
        Task {
            do {
                async let categoriesTask = categoriesService.fetchCategories(direction: transaction.direction)
                async let accountsTask = accountsService.fetchAccounts()
                
                let (cats, accs) = try await (categoriesTask, accountsTask)
                await MainActor.run {
                    categories = cats
                    accounts = accs
                    selectedCategory = cats.first { $0.id == transaction.categoryId }
                    selectedAccount = accs.first { $0.id == transaction.accountId }
                    
                    let initial = AmountTextField.formatAmount(transaction.amount, formatter: formatter)
                    amount = initial
                    previousAmount = initial
                    date = transaction.transactionDate
                    comment = transaction.comment ?? ""
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showLoadError = true
                }
            }
        }
    }
    
    private func save() {
        guard let decimalAmount = AmountTextField.parseAmount(amount),
              let category = selectedCategory else { return }
        
        let updated = Transaction(
            id: transaction.id,
            accountId: selectedAccount?.id ?? transaction.accountId,
            categoryId: category.id,
            amount: decimalAmount,
            transactionDate: date,
            comment: comment.isEmpty ? nil : comment,
            createdAt: transaction.createdAt,
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            direction: transaction.direction
        )
        
        onSave(updated)
        dismiss()
    }
}
