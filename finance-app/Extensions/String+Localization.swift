import Foundation

extension String {
    var appLocalized: String {
        let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? AppLanguage.russian.rawValue
        return appLocalized(for: AppLanguage(rawValue: languageCode) ?? .russian)
    }

    func appLocalized(for language: AppLanguage) -> String {
        let languageCode = language.rawValue
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return self
        }
        return bundle.localizedString(forKey: self, value: self, table: nil)
    }
}
