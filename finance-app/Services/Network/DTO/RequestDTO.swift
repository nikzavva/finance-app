import Foundation

struct CreateTransactionRequest: Encodable {
    let accountId: Int
    let categoryId: Int
    let amount: Decimal
    let transactionDate: Date
    let comment: String?
}

struct UpdateTransactionRequest: Encodable {
    let accountId: Int
    let categoryId: Int
    let amount: Decimal
    let transactionDate: Date
    let comment: String?
}

struct CreateAccountRequest: Encodable {
    let name: String
    let emoji: String
    let balance: Decimal
    let currency: String
}

struct UpdateAccountRequest: Encodable {
    let name: String
    let emoji: String
    let balance: Decimal
    let currency: String
}
