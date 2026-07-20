import Foundation

extension Transaction {
    static func parse(csvRow: String, separator: Character = ",") -> Transaction? {
        let components = csvRow.split(separator: separator, omittingEmptySubsequences: false)
        guard components.count >= 7 else { return nil }
        guard let id = Int(components[0]),
              let accountId = Int(components[1]),
              let categoryId = Int(components[2])
        else { return nil }
        let amountString = components[3].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Decimal(string: amountString) else { return nil }
        let dateString = components[4].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let date = ISO8601DateFormatter().date(from: dateString) else { return nil }
        let comment = components[5].trimmingCharacters(in: .whitespacesAndNewlines)
        let directionString = components[6].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let direction = Direction(rawValue: directionString) else { return nil }
        
        let createdAt = components.count > 7 ? String(components[7]) : nil
        let updatedAt = components.count > 8 ? String(components[8]) : nil
        return Transaction(
            id: id,
            accountId: accountId,
            categoryId: categoryId,
            amount: amount,
            transactionDate: date,
            comment: comment.isEmpty ? nil : comment,
            createdAt: createdAt,
            updatedAt: updatedAt,
            direction: direction
        )
    }
}
