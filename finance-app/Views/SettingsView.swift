import SwiftUI

struct SettingsView: View {
    private enum Destination: Identifiable {
        case currency
        case categories
        case theme
        case language
        case pin
        case biometrics

        var id: String {
            switch self {
            case .currency: "currency"
            case .categories: "categories"
            case .theme: "theme"
            case .language: "language"
            case .pin: "pin"
            case .biometrics: "biometrics"
            }
        }
    }

    let categoryDirection: Direction?
    let onCategorySelected: (Category, Direction) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var security: AppSecurityManager
    @State private var destination: Destination?

    var body: some View {
        NavigationStack {
            List {
                Section(settings.language.text("Кошелёк", "Wallet")) {
                    Button { destination = .currency } label: {
                        SettingsRow(
                            title: settings.language.text("Валюта", "Currency"),
                            value: settings.currency.title(for: settings.language)
                        )
                    }
                    .buttonStyle(.plain)

                    Button { destination = .categories } label: {
                        SettingsRow(
                            title: settings.language.text("Статьи", "Categories"),
                            value: categoryDirection.map(categoryDirectionTitle) ?? settings.language.text("Недоступно", "Unavailable")
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(categoryDirection == nil)
                }

                Section(settings.language.text("Интерфейс", "Interface")) {
                    Button { destination = .theme } label: {
                        SettingsRow(
                            title: settings.language.text("Тема оформления", "Appearance"),
                            value: settings.theme.title(for: settings.language)
                        )
                    }
                    .buttonStyle(.plain)

                    Button { destination = .language } label: {
                        SettingsRow(
                            title: settings.language.text("Язык", "Language"),
                            value: settings.language.title
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section(settings.language.text("Безопасность", "Security")) {
                    Button { destination = .pin } label: {
                        SettingsRow(
                            title: settings.language.text("PIN-код", "PIN code"),
                            value: security.hasPIN
                                ? settings.language.text("Установлен", "Set")
                                : settings.language.text("Не установлен", "Not set")
                        )
                    }
                    .buttonStyle(.plain)

                    Button { destination = .biometrics } label: {
                        SettingsRow(
                            title: security.biometryName,
                            value: security.useBiometrics
                                ? settings.language.text("Включена", "On")
                                : settings.language.text("Выключена", "Off")
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(settings.language.text("Настройки", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(item: $destination) { destination in
            switch destination {
            case .currency:
                SettingsChoiceView(
                    title: settings.language.text("Валюта", "Currency"),
                    choices: AppCurrency.allCases,
                    selected: $settings.currency,
                    choiceTitle: { $0.title(for: settings.language) }
                )
            case .categories:
                if let categoryDirection {
                    CategorySelectionView(direction: categoryDirection) { category in
                        onCategorySelected(category, categoryDirection)
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            case .theme:
                SettingsChoiceView(
                    title: settings.language.text("Тема оформления", "Appearance"),
                    choices: AppTheme.allCases,
                    selected: $settings.theme,
                    choiceTitle: { $0.title(for: settings.language) }
                )
            case .language:
                SettingsChoiceView(
                    title: settings.language.text("Язык", "Language"),
                    choices: AppLanguage.allCases,
                    selected: $settings.language,
                    choiceTitle: \.title
                )
            case .pin:
                SettingsPINView()
            case .biometrics:
                SettingsBiometricsView()
            }
        }
    }

    private func categoryDirectionTitle(_ direction: Direction) -> String {
        switch direction {
        case .income:
            settings.language.text("Доходы", "Income")
        case .outcome:
            settings.language.text("Расходы", "Expenses")
        }
    }
}

private struct SettingsRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct SettingsChoiceView<Choice: Identifiable & Hashable>: View {
    let title: String
    let choices: [Choice]
    @Binding var selected: Choice
    let choiceTitle: (Choice) -> String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(choices) { choice in
                Button {
                    selected = choice
                } label: {
                    HStack {
                        Text(choiceTitle(choice))
                            .foregroundStyle(.primary)
                        Spacer()
                        if selected == choice {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct SettingsPINView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var security: AppSecurityManager
    @EnvironmentObject private var settings: AppSettings
    @State private var pin = ""
    @State private var showValidationError = false

    var body: some View {
        NavigationStack {
            VStack {
                Text(
                    security.hasPIN
                        ? settings.language.text("Введите новый PIN-код", "Enter a new PIN code")
                        : settings.language.text("Задайте PIN-код", "Set a PIN code")
                )
                .font(.body)
                .foregroundStyle(.secondary)

                SecureField("PIN", text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.title2.monospacedDigit())
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: pin) { _, value in
                        pin = String(value.filter(\.isNumber).prefix(4))
                    }

                Button(settings.language.text("Сохранить", "Save")) {
                    if security.setPIN(pin) {
                        dismiss()
                    } else {
                        showValidationError = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(pin.count != 4)

                Spacer()
            }
            .padding()
            .navigationTitle(settings.language.text("PIN-код", "PIN code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .alert(settings.language.text("PIN-код должен содержать 4 цифры", "PIN code must contain 4 digits"), isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            }
        }
        .presentationDetents([.medium])
    }
}

private struct SettingsBiometricsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var security: AppSecurityManager
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(
                        security.biometryName,
                        isOn: $security.useBiometrics
                    )
                    .disabled(!security.isBiometricsAvailable || !security.hasPIN)
                } footer: {
                    if !security.hasPIN {
                        Text(settings.language.text("Сначала задайте PIN-код", "Set a PIN code first"))
                    } else if !security.isBiometricsAvailable {
                        Text(settings.language.text("Биометрия недоступна на этом устройстве", "Biometrics are unavailable on this device"))
                    }
                }
            }
            .navigationTitle(security.biometryName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
