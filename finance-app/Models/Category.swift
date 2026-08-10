struct Category: Equatable {
    let id: Int
    let name: String
    let emoji: Character
    let isIncome: Bool
    
    var direction: Direction {
        return isIncome ? .income : .outcome
    }

    var localizedName: String {
        name.appLocalized
    }

    func localizedName(for language: AppLanguage) -> String {
        name.appLocalized(for: language)
    }
}
