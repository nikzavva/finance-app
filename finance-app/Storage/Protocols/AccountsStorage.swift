protocol AccountsStorage {
    func fetchAll() async throws -> [BankAccount]
    func fetch(byId id: Int) async throws -> BankAccount?
    func create(_ account: BankAccount) async throws
    func update(_ account: BankAccount) async throws
    func delete(byId id: Int) async throws
    func deleteAll() async throws
}
