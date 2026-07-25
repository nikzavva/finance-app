import SwiftUI

struct CreateTransactionView: View {
    let direction: Direction
    let initialAccount: BankAccount?
    let onCreate: (Transaction) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var amount: String = "0"
    @State private var previousAmount: String = "0"
    @State private var date: Date = Date()
    @State private var comment: String = ""
    @State private var selectedCategory: Category?
    @State private var selectedAccount: BankAccount?
    @State private var showCategorySelection = false
    @State private var showAccountSelection = false
    @State private var showValidationError = false
    @State private var showLoadError = false
    @State private var errorMessage = ""
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isCommentFocused: Bool
    
    private let categoriesService = CategoriesService()
    private let accountsService = BankAccountsService()
    private let transactionService = TransactionsService()
    @State private var categories: [Category] = []
    @State private var accounts: [BankAccount] = []
    
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
            .navigationTitle(direction == .income ? "Внести доход" : "Внести расход")
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
                CategorySelectionView(direction: direction) { category in
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
            .alert("Заполните все поля", isPresented: $showValidationError) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text("Сумма должна быть больше 0 и статья обязательна")
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
        return selectedCategory != nil
    }

    private func loadInitialData() {
        Task {
            do {
                async let categoriesTask = categoriesService.fetchCategories(direction: direction)
                async let accountsTask = accountsService.fetchAccounts()
                
                let (cats, accs) = try await (categoriesTask, accountsTask)
                await MainActor.run {
                    categories = cats
                    accounts = accs
                    
                    if accs.isEmpty {
                        errorMessage = "Сначала создайте счёт в разделе «Счета»"
                        showLoadError = true
                    } else if let initial = initialAccount {
                        selectedAccount = initial
                    } else {
                        selectedAccount = accs.first
                    }
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
              let category = selectedCategory,
              let account = selectedAccount else { return }
        
        let newTransaction = Transaction(
            id: 0,
            accountId: account.id,
            categoryId: category.id,
            amount: decimalAmount,
            transactionDate: date,
            comment: comment.isEmpty ? nil : comment,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            direction: direction
        )
        
        onCreate(newTransaction)
        dismiss()
    }
}
