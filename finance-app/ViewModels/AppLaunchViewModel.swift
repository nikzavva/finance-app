import Combine
import Foundation

@MainActor
final class AppLaunchViewModel: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var isSplashFinished = false
    @Published var showMigrationError = false
    @Published private(set) var migrationErrorMessage = ""

    private let storageManager: StorageManaging
    private var hasPrepared = false

    init(storageManager: StorageManaging) {
        self.storageManager = storageManager
    }

    func prepare() async {
        guard !hasPrepared else { return }
        hasPrepared = true

        do {
            try await storageManager.migrateIfNeeded()
        } catch {
            migrationErrorMessage = error.localizedDescription
            showMigrationError = isSplashFinished
        }

        isReady = true
    }

    func splashDidFinish() {
        isSplashFinished = true
        showMigrationError = !migrationErrorMessage.isEmpty
    }
}
