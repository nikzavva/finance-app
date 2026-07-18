import Foundation

struct BankAccount: Identifiable {
    let id: Int
    let userId: Int
    let name: String
    let emoji: String
    let balance: Decimal
    let currency: String
    let createdAt: String
    let updatedAt: String
}
