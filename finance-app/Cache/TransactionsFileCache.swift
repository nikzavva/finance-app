import Foundation

final class TransactionsFileCache {
    private let fileURL: URL
    private(set) var transactions: [Transaction] = []
    
    init(fileName: String) {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fileURL = URL(fileURLWithPath: "")
            return
        }
        fileURL = documents.appendingPathComponent(fileName).appendingPathExtension("json")
        try? load()
    }
    
    func addTransaction(_ transaction: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index] = transaction
        } else {
            transactions.append(transaction)
        }
        try? save()
    }
    
    func removeTransaction(by id: Int) {
        transactions.removeAll { $0.id == id }
        try? save()
    }
    
    func save() throws {
        let jsonArray = transactions.map { $0.jsonObject }
        let data = try JSONSerialization.data(withJSONObject: jsonArray, options: .prettyPrinted)
        try data.write(to: fileURL)
    }
    
    func load() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data = try Data(contentsOf: fileURL)
        let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] ?? []
        transactions = jsonArray.compactMap { Transaction.parse(jsonObject: $0) }
    }
}
