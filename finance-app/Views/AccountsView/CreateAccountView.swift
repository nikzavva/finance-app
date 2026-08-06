import SwiftUI

struct CreateAccountView: View {
    let onCreate: (BankAccount) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateAccountViewModel()
    @FocusState private var isNameFocused: Bool
    @FocusState private var isAmountFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: .zero) {
                AmountTextField(
                    amount: $viewModel.amount,
                    previousAmount: $viewModel.previousAmount,
                    isFocused: $isAmountFocused,
                    maxAmount: Constants.maxAmountBankAccount
                )
                
                HStack {
                    Text("Название")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    TextField("", text: $viewModel.name, prompt: Text("Например, основной").foregroundColor(.secondary))
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(viewModel.popularEmojis, id: \.self) { emojiItem in
                                Button {
                                    viewModel.emoji = emojiItem
                                } label: {
                                    Text(emojiItem)
                                        .font(.title2)
                                        .frame(width: UIConstants.Sizes.icon, height: UIConstants.Sizes.icon)
                                        .background(viewModel.emoji == emojiItem ? Color.accentColor : Color.clear)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
                    DatePicker("", selection: $viewModel.date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
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
                        guard let account = viewModel.submit() else { return }
                        onCreate(account)
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.body)
                            .foregroundColor(.accentColor)
                    }
                    .disabled(viewModel.isSubmitting)
                }
            }
            .alert("Заполните все поля", isPresented: $viewModel.showValidationError) {
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
}
