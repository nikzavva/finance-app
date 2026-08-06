import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var useCoreData: Bool
    @Published private(set) var isMigrating = false
    @Published var showMigrationError = false
    @Published private(set) var migrationErrorMessage = ""

    private let storageManager: StorageManaging
    private let userDefaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private var appliedUseCoreData: Bool

    init(
        storageManager: StorageManaging? = nil,
        userDefaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default
    ) {
        userDefaults.register(defaults: ["use_coredata": false])
        let useCoreData = userDefaults.bool(forKey: "use_coredata")
        self.useCoreData = useCoreData
        self.appliedUseCoreData = useCoreData
        self.storageManager = storageManager ?? StorageManager.shared
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
    }

    func requestStorageChange(to newValue: Bool) {
        guard newValue != appliedUseCoreData else { return }
        guard !isMigrating else {
            useCoreData = appliedUseCoreData
            return
        }

        isMigrating = true
        userDefaults.set(newValue, forKey: "use_coredata")

        Task {
            await changeStorage(to: newValue)
        }
    }

    private func changeStorage(to newValue: Bool) async {
        do {
            try await storageManager.switchStorage(to: newValue ? .coreData : .swiftData)
            appliedUseCoreData = newValue
            notificationCenter.post(name: .transactionsDidChange, object: nil)
            notificationCenter.post(name: .accountsDidChange, object: nil)
        } catch {
            userDefaults.set(appliedUseCoreData, forKey: "use_coredata")
            useCoreData = appliedUseCoreData
            migrationErrorMessage = error.localizedDescription
            showMigrationError = true
        }

        isMigrating = false
    }
}
