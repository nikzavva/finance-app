import Foundation

struct TransactionDTO: Codable {
    let id: Int
    let account: AccountBriefDTO
    let category: CategoryDTO
    let amount: String
    let transactionDate: Date
    let comment: String?
    let createdAt: String
    let updatedAt: String
    
    nonisolated func toDomain() -> Transaction {
        Transaction(
            id: id,
            accountId: account.id,
            categoryId: category.id,
            amount: Decimal(string: amount) ?? 0,
            transactionDate: transactionDate,
            comment: comment,
            createdAt: createdAt,
            updatedAt: updatedAt,
            direction: category.isIncome ? .income : .outcome
        )
    }
}

struct AccountBriefDTO: Codable {
    let id: Int
    let name: String
    let balance: String
    let currency: String
}

struct TransactionRequestDTO: Encodable {
    let accountId: Int
    let categoryId: Int
    let amount: String
    let transactionDate: Date
    let comment: String?
    
    init(from transaction: Transaction) {
        self.accountId = transaction.accountId
        self.categoryId = transaction.categoryId
        
        let ns = transaction.amount as NSDecimalNumber
        self.amount = String(format: "%.2f", ns.doubleValue)
        
        self.transactionDate = transaction.transactionDate
        self.comment = transaction.comment
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(categoryId, forKey: .categoryId)
        try container.encode(amount, forKey: .amount)
        try container.encode(transactionDate, forKey: .transactionDate)
        if let comment = comment {
            try container.encode(comment, forKey: .comment)
        } else {
            try container.encodeNil(forKey: .comment)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case accountId, categoryId, amount, transactionDate, comment
    }
}

struct TransactionCreatedDTO: Codable {
    let id: Int
    let accountId: Int
    let categoryId: Int
    let amount: String
    let transactionDate: Date
    let comment: String?
    let createdAt: String
    let updatedAt: String
    
    nonisolated func toDomain(direction: Direction) -> Transaction {
        Transaction(
            id: id,
            accountId: accountId,
            categoryId: categoryId,
            amount: Decimal(string: amount) ?? 0,
            transactionDate: transactionDate,
            comment: comment,
            createdAt: createdAt,
            updatedAt: updatedAt,
            direction: direction
        )
    }
}
