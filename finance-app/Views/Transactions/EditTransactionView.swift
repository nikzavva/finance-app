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
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isCommentFocused: Bool
    
    private let maxAmount: Decimal = 9_999_999
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
                TextField("", text: $amount)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .font(.system(size: UIConstants.Sizes.totalAmountFontSize, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top)
                    .padding(.bottom)
                    .onChange(of: amount) { _, newValue in
                        formatInput(newValue)
                    }
                
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color(.systemGray3))
                        .frame(width: geometry.size.width * 2/3, height: 1)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 1)
                .padding(.bottom)
                
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
                    DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
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
                    Button(action: save) {
                        Image(systemName: "checkmark")
                            .font(.body)
                            .foregroundColor(isValid ? .accentColor : .gray)
                    }
                    .disabled(!isValid)
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
        parseAmount(amount) != nil && selectedCategory != nil
    }
    
    private func loadInitialData() {
        Task {
            async let categoriesTask = categoriesService.fetchCategories(direction: transaction.direction)
            async let accountsTask = accountsService.fetchAccounts()
            
            let (cats, accs) = await (categoriesTask, accountsTask)
            await MainActor.run {
                categories = cats
                accounts = accs
                selectedCategory = cats.first { $0.id == transaction.categoryId }
                selectedAccount = accs.first { $0.id == transaction.accountId }
                
                let initial = formatAmount(transaction.amount)
                amount = initial
                previousAmount = initial
                date = transaction.transactionDate
                comment = transaction.comment ?? ""
            }
        }
    }
    
    private func save() {
        guard let decimalAmount = parseAmount(amount),
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
    
    private func formatAmount(_ value: Decimal) -> String {
        let number = value as NSDecimalNumber
        return formatter.string(from: number) ?? "0"
    }
    
    private func parseAmount(_ string: String) -> Decimal? {
        let cleaned = string.replacingOccurrences(of: " ", with: "")
                          .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleaned)
    }
    
    private func formatInput(_ input: String) {
        let filtered = input.replacingOccurrences(
            of: "[^\\d\\s,.]",
            with: "",
            options: .regularExpression
        )
        
        let cleaned = filtered.replacingOccurrences(of: " ", with: "")
                              .replacingOccurrences(of: ",", with: ".")
        
        if cleaned.isEmpty {
            amount = "0"
            previousAmount = "0"
            return
        }
        
        guard let decimal = Decimal(string: cleaned) else {
            return
        }
        
        if decimal > maxAmount {
            amount = previousAmount
            return
        }
        
        let formatted = formatAmount(decimal)
        amount = formatted
        previousAmount = formatted
    }
}
