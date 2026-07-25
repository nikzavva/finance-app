protocol TransactionsStorage {
    func fetchAll() async throws -> [Transaction]
    func fetch(byIds ids: [Int]) async throws -> [Transaction]
    func create(_ transaction: Transaction) async throws
    func update(_ transaction: Transaction) async throws
    func delete(byId id: Int) async throws
    func deleteAll() async throws
}
