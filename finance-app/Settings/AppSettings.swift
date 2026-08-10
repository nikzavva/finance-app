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
            return "Рубли".appLocalized(for: language)
        case .dollar:
            return "Доллары".appLocalized(for: language)
        case .euro:
            return "Евро".appLocalized(for: language)
        case .pound:
            return "Фунты".appLocalized(for: language)
        case .yuan:
            return "Юани".appLocalized(for: language)
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
            return "Системная".appLocalized(for: language)
        case .light:
            return "Светлая".appLocalized(for: language)
        case .dark:
            return "Тёмная".appLocalized(for: language)
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
        case .russian: "Русский".appLocalized(for: .russian)
        case .english: "English".appLocalized(for: .english)
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
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
    @Published var hapticsEnabled: Bool {
        didSet { userDefaults.set(hapticsEnabled, forKey: Self.hapticsKey) }
    }

    private static let currencyKey = "app_currency"
    private static let themeKey = "app_theme"
    private static let languageKey = "app_language"
    static let hapticsKey = "app_haptics_enabled"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        currency = AppCurrency(rawValue: userDefaults.string(forKey: Self.currencyKey) ?? "") ?? .ruble
        theme = AppTheme(rawValue: userDefaults.string(forKey: Self.themeKey) ?? "") ?? .system
        language = AppLanguage(rawValue: userDefaults.string(forKey: Self.languageKey) ?? "") ?? .russian
        hapticsEnabled = userDefaults.object(forKey: Self.hapticsKey) as? Bool ?? true
    }

    static var currentCurrency: AppCurrency {
        AppCurrency(rawValue: UserDefaults.standard.string(forKey: currencyKey) ?? "") ?? .ruble
    }

    static var currentLanguage: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: languageKey) ?? "") ?? .russian
    }

    static var currentHapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: hapticsKey) as? Bool ?? true
    }
}
