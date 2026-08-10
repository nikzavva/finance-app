import SwiftUI

struct SettingsView: View {
    private enum Destination: Identifiable {
        case currency
        case categories
        case theme
        case language
        case pin

        var id: String {
            switch self {
            case .currency: "currency"
            case .categories: "categories"
            case .theme: "theme"
            case .language: "language"
            case .pin: "pin"
            }
        }
    }

    let categoryDirection: Direction?
    let selectedCategory: Category?
    let onCategorySelected: (Category, Direction) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var security: AppSecurityManager
    @State private var destination: Destination?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: UIConstants.Spacing.settingsSection) {
                    SettingsSection(title: "Кошелёк".appLocalized(for: settings.language)) {
                    Button { destination = .currency } label: {
                        SettingsRow(
                            title: "Валюта".appLocalized(for: settings.language),
                            value: settings.currency.title(for: settings.language)
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()

                    Button { destination = .categories } label: {
                        SettingsRow(
                            title: "Статьи".appLocalized(for: settings.language),
                            value: categoryDirection.map(categoryDirectionTitle) ?? "Недоступно".appLocalized(for: settings.language)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(categoryDirection == nil)
                    }

                    SettingsSection(title: "Интерфейс".appLocalized(for: settings.language)) {
                    Button { destination = .theme } label: {
                        SettingsRow(
                            title: "Тема оформления".appLocalized(for: settings.language),
                            value: settings.theme.title(for: settings.language)
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()

                    Button { destination = .language } label: {
                        SettingsRow(
                            title: "Язык".appLocalized(for: settings.language),
                            value: settings.language.title
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()

                    Toggle(
                        "Хаптики".appLocalized(for: settings.language),
                        isOn: $settings.hapticsEnabled
                    )
                    .toggleStyle(.switch)
                    .padding(.vertical)
                    .onChange(of: settings.hapticsEnabled) { _, enabled in
                        if enabled {
                            HapticsManager.shared.play(.selection)
                        }
                    }
                    }

                    SettingsSection(title: "Безопасность".appLocalized(for: settings.language)) {
                    Button { destination = .pin } label: {
                        SettingsRow(
                            title: "PIN-код".appLocalized(for: settings.language),
                            value: security.hasPIN
                                ? "Установлен".appLocalized(for: settings.language)
                                : "Не установлен".appLocalized(for: settings.language)
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()

                    Toggle(
                        security.biometryName,
                        isOn: Binding(
                            get: { security.useBiometrics },
                            set: { isEnabled in
                                if isEnabled {
                                    Task { await security.enableBiometrics() }
                                } else {
                                    security.disableBiometrics()
                                }
                            }
                        )
                    )
                    .toggleStyle(.switch)
                    .padding(.vertical)
                    .disabled(
                        !security.isBiometricsAvailable ||
                        !security.hasPIN ||
                        security.isAuthenticatingBiometrics
                    )
                    }

                    DeleteAllDataButton()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical)
            }
            .navigationTitle("Настройки".appLocalized(for: settings.language))
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
        .id(settings.theme)
        .settingsTheme(settings.theme)
        .adaptivePresentationDetents(
            iPhone: [.medium, .large],
            iPad: [.large]
        )
        .sheet(item: $destination) { destination in
            switch destination {
            case .currency:
                SettingsChoiceView(
                    titleKey: "Валюта",
                    choices: AppCurrency.allCases,
                    selected: $settings.currency,
                    choiceTitle: { $0.title(for: settings.language) }
                )
            case .categories:
                if let categoryDirection {
                    CategorySelectionView(
                        direction: categoryDirection,
                        selectedCategoryID: selectedCategory?.id,
                        dismissesOnSelection: false
                    ) { category in
                        onCategorySelected(category, categoryDirection)
                    }
                    .adaptivePresentationDetents(
                        iPhone: [.medium, .large],
                        iPad: [.large]
                    )
                    .presentationDragIndicator(.visible)
                }
            case .theme:
                SettingsChoiceView(
                    titleKey: "Тема оформления",
                    choices: AppTheme.allCases,
                    selected: $settings.theme,
                    choiceTitle: { $0.title(for: settings.language) }
                )
            case .language:
                SettingsChoiceView(
                    titleKey: "Язык",
                    choices: AppLanguage.allCases,
                    selected: $settings.language,
                    choiceTitle: \.title
                )
            case .pin:
                PINCodeView(mode: .change)
            }
        }
    }

    private func categoryDirectionTitle(_ direction: Direction) -> String {
        switch direction {
        case .income:
            "Доходы".appLocalized(for: settings.language)
        case .outcome:
            "Расходы".appLocalized(for: settings.language)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: .zero) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .padding(.vertical)
        .contentShape(Rectangle())
    }
}

private struct SettingsChoiceView<Choice: Identifiable & Hashable>: View {
    let titleKey: String
    let choices: [Choice]
    @Binding var selected: Choice
    let choiceTitle: (Choice) -> String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: .zero) {
                    ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
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
                            .padding(.vertical)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < choices.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .padding(.horizontal)
            .navigationTitle(titleKey.appLocalized(for: settings.language))
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
        .id(settings.theme)
        .settingsTheme(settings.theme)
        .adaptivePresentationDetents(iPhone: [.medium], iPad: [.large])
    }
}

private extension View {
    @ViewBuilder
    func settingsTheme(_ theme: AppTheme) -> some View {
        if let colorScheme = theme.colorScheme {
            environment(\.colorScheme, colorScheme)
                .preferredColorScheme(colorScheme)
        } else {
            preferredColorScheme(nil)
        }
    }
}
