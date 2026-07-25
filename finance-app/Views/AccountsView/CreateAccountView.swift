import SwiftUI

struct CreateAccountView: View {
    let onCreate: (BankAccount) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var emoji: String = "💰"
    @State private var amount: String = "0"
    @State private var previousAmount: String = "0"
    @State private var date: Date = Date()
    @State private var showValidationError = false
    @FocusState private var isNameFocused: Bool
    @FocusState private var isAmountFocused: Bool
    
    private let popularEmojis = ["💰", "💳", "💵", "💸", "🏦", "🏠", "🚗", "🎒", "📱", "🎯", "🎁", "💼", "🍔", "☕", "🏥", "✈️", "🛒", "💡", "📚", "🎬"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: .zero) {
                AmountTextField(
                    amount: $amount,
                    previousAmount: $previousAmount,
                    isFocused: $isAmountFocused,
                    maxAmount: Constants.maxAmountBankAccount
                )
                
                HStack {
                    Text("Название")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    TextField("", text: $name, prompt: Text("Например, основной").foregroundColor(.secondary))
                        .multilineTextAlignment(.trailing)
                        .focused($isNameFocused)
                        .font(.body)
                }
                .padding(.horizontal)
                .padding(.vertical)
                
                Divider()
                    .padding(.horizontal)
                
                HStack {
                    Text("Иконка")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(popularEmojis, id: \.self) { emojiItem in
                                Button {
                                    emoji = emojiItem
                                } label: {
                                    Text(emojiItem)
                                        .font(.title2)
                                        .frame(width: 40, height: 40)
                                        .background(emoji == emojiItem ? Color.accentColor.opacity(0.2) : Color.clear)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: 180)
                }
                .padding(.horizontal)
                .padding(.vertical)
                
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
                
                HStack {
                    Text("Валюта")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("Руб.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical)
                
                Divider()
                    .padding(.horizontal)
                
                Spacer()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Новый счёт")
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
            .alert("Заполните все поля", isPresented: $showValidationError) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text("Название и сумма обязательны")
            }
            .gesture(
                DragGesture()
                    .onEnded { _ in
                        isNameFocused = false
                        isAmountFocused = false
                    }
            )
        }
        .presentationDetents([.medium])
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        AmountTextField.parseAmount(amount) != nil
    }
    
    private func save() {
        guard let decimalAmount = AmountTextField.parseAmount(amount) else { return }
        
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: date)
        
        let newAccount = BankAccount(
            id: 0,
            userId: 0,
            name: name.trimmingCharacters(in: .whitespaces),
            emoji: emoji,
            balance: decimalAmount,
            currency: "RUB",
            createdAt: dateString,
            updatedAt: dateString
        )
        
        onCreate(newAccount)
        dismiss()
    }
}
