struct Category: Equatable {
    let id: Int
    let name: String
    let emoji: Character
    let isIncome: Bool
    
    var direction: Direction {
        return isIncome ? .income : .outcome
    }
}
