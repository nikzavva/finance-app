import Combine
import SwiftUI

enum AppCurrency: String, CaseIterable, Identifiable {
    case ruble = "RUB"
    case dollar = "USD"
    case euro = "EUR"
    case pound = "GBP"
    case yuan = "CNY"

    var id: String { rawValue }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .ruble:
            return language == .english ? "Russian ruble" : "Рубли"
        case .dollar:
            return language == .english ? "US dollar" : "Доллары"
        case .euro:
            return language == .english ? "Euro" : "Евро"
        case .pound:
            return language == .english ? "Pound sterling" : "Фунты"
        case .yuan:
            return language == .english ? "Chinese yuan" : "Юани"
        }
    }

    var symbol: String {
        switch self {
        case .ruble: "₽"
        case .dollar: "$"
        case .euro: "€"
        case .pound: "£"
        case .yuan: "¥"
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .system:
            return language == .english ? "System" : "Системная"
        case .light:
            return language == .english ? "Light" : "Светлая"
        case .dark:
            return language == .english ? "Dark" : "Тёмная"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .russian: "Русский"
        case .english: "English"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    func text(_ russian: String, _ english: String) -> String {
        self == .english ? english : russian
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var currency: AppCurrency {
        didSet { userDefaults.set(currency.rawValue, forKey: Self.currencyKey) }
    }
    @Published var theme: AppTheme {
        didSet { userDefaults.set(theme.rawValue, forKey: Self.themeKey) }
    }
    @Published var language: AppLanguage {
        didSet { userDefaults.set(language.rawValue, forKey: Self.languageKey) }
    }

    private static let currencyKey = "app_currency"
    private static let themeKey = "app_theme"
    private static let languageKey = "app_language"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        currency = AppCurrency(rawValue: userDefaults.string(forKey: Self.currencyKey) ?? "") ?? .ruble
        theme = AppTheme(rawValue: userDefaults.string(forKey: Self.themeKey) ?? "") ?? .system
        language = AppLanguage(rawValue: userDefaults.string(forKey: Self.languageKey) ?? "") ?? .russian
    }

    static var currentCurrency: AppCurrency {
        AppCurrency(rawValue: UserDefaults.standard.string(forKey: currencyKey) ?? "") ?? .ruble
    }
}
