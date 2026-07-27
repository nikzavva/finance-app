import Foundation

struct CreateAccountRequestDTO: Encodable {
    let name: String
    let emoji: String
    let balance: String
    let currency: String
    
    init(from account: BankAccount) {
        self.name = account.name
        self.emoji = account.emoji
        
        let ns = account.balance as NSDecimalNumber
        self.balance = String(format: "%.2f", ns.doubleValue)
        
        self.currency = account.currency
    }
}

struct UpdateAccountRequestDTO: Encodable {
    let name: String
    let emoji: String
    let balance: String
    let currency: String
    
    init(from account: BankAccount) {
        self.name = account.name
        self.emoji = account.emoji
        
        let ns = account.balance as NSDecimalNumber
        self.balance = String(format: "%.2f", ns.doubleValue)
        
        self.currency = account.currency
    }
}
