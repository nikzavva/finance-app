import Foundation

extension Transaction {
    static func parse(jsonObject: Any) -> Transaction? {
        guard let dict = jsonObject as? [String: Any],
              let id = dict["id"] as? Int,
              let accountId = dict["accountId"] as? Int,
              let categoryId = dict["categoryId"] as? Int,
              let amountString = dict["amount"] as? String,
              let amount = Decimal(string: amountString),
              let transactionDateString = dict["transactionDate"] as? String,
              let transactionDate = ISO8601DateFormatter().date(from: transactionDateString),
              let directionString = dict["direction"] as? String,
              let direction = Direction(rawValue: directionString)
        else { return nil }
        
        let comment = dict["comment"] as? String
        let createdAt = dict["createdAt"] as? String
        let updatedAt = dict["updatedAt"] as? String
        
        return Transaction(
            id: id,
            accountId: accountId,
            categoryId: categoryId,
            amount: amount,
            transactionDate: transactionDate,
            comment: comment,
            createdAt: createdAt,
            updatedAt: updatedAt,
            direction: direction
        )
    }
    
    var jsonObject: Any {
        let dateFormatter = ISO8601DateFormatter()
        let dict: [String: Any] = [
            "id": id,
            "accountId": accountId,
            "categoryId": categoryId,
            "amount": "\(amount)",
            "transactionDate": dateFormatter.string(from: transactionDate),
            "createdAt": createdAt ?? NSNull(),
            "updatedAt": updatedAt ?? NSNull(),
            "direction": direction == .income ? "income" : "outcome",
            "comment": comment as Any
        ]
        return dict
    }
}
