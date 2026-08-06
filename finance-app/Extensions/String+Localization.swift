import Foundation

extension String {
    var appLocalized: String {
        let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? AppLanguage.russian.rawValue
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return self
        }
        return bundle.localizedString(forKey: self, value: self, table: nil)
    }
}
