import Foundation

nonisolated enum DataResource: Hashable {
    case transaction(Int)
    case account(Int)
}

actor DataMutationCoordinator {
    static let shared = DataMutationCoordinator()

    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func withLock<T>(_ operation: () async throws -> T) async rethrows -> T {
        await acquire()
        defer { release() }
        return try await operation()
    }

    private func acquire() async {
        guard isLocked else {
            isLocked = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        guard !waiters.isEmpty else {
            isLocked = false
            return
        }

        waiters.removeFirst().resume()
    }
}

actor InFlightDataRegistry {
    static let shared = InFlightDataRegistry()

    private var resources = Set<DataResource>()
    private var waiters: [DataResource: [CheckedContinuation<Void, Never>]] = [:]

    func begin(_ resource: DataResource) -> Bool {
        resources.insert(resource).inserted
    }

    func acquire(_ resource: DataResource) async {
        guard !resources.insert(resource).inserted else { return }

        await withCheckedContinuation { continuation in
            waiters[resource, default: []].append(continuation)
        }
    }

    func end(_ resource: DataResource) {
        if var resourceWaiters = waiters[resource], !resourceWaiters.isEmpty {
            let continuation = resourceWaiters.removeFirst()
            if resourceWaiters.isEmpty {
                waiters.removeValue(forKey: resource)
            } else {
                waiters[resource] = resourceWaiters
            }
            continuation.resume()
            return
        }

        resources.remove(resource)
    }
}

actor TemporaryIDGenerator {
    static let shared = TemporaryIDGenerator()

    private var lastID = 1_000_000_000

    func next() -> Int {
        let timestamp = Int(Date().timeIntervalSince1970 * 1_000)
        lastID = max(lastID + 1, timestamp)
        return lastID
    }
}
