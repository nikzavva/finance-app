import Combine
import Foundation
import LocalAuthentication
import Security

@MainActor
final class AppSecurityManager: ObservableObject {
    @Published private(set) var isLocked: Bool
    @Published private(set) var hasPIN: Bool
    @Published private(set) var isAuthenticatingBiometrics = false
    @Published var useBiometrics: Bool {
        didSet { userDefaults.set(useBiometrics, forKey: Self.biometricsKey) }
    }

    private static let biometricsKey = "use_biometrics"
    private static let installationMarkerKey = "security_installation_marker"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if userDefaults.object(forKey: Self.installationMarkerKey) == nil {
            PINKeychain.delete()
            userDefaults.removeObject(forKey: Self.biometricsKey)
            userDefaults.set(UUID().uuidString, forKey: Self.installationMarkerKey)
        }
        let hasPIN = PINKeychain.read() != nil
        self.hasPIN = hasPIN
        self.isLocked = hasPIN
        self.useBiometrics = userDefaults.bool(forKey: Self.biometricsKey)
    }

    var biometryName: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Биометрия".appLocalized
        }
        return switch context.biometryType {
        case .faceID: "Face ID".appLocalized
        case .touchID: "Touch ID".appLocalized
        default: "Биометрия".appLocalized
        }
    }

    var isBiometricsAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func setPIN(_ pin: String) -> Bool {
        guard pin.count == 4, pin.allSatisfy(\.isNumber), PINKeychain.save(pin) else { return false }
        hasPIN = true
        isLocked = false
        return true
    }

    func completeInitialSetup(pin: String, useBiometrics: Bool) -> Bool {
        guard pin.count == 4,
              pin.allSatisfy(\.isNumber),
              PINKeychain.save(pin) else {
            return false
        }
        self.useBiometrics = useBiometrics
        hasPIN = true
        isLocked = false
        return true
    }

    func unlock(with pin: String) -> Bool {
        guard PINKeychain.read() == pin else { return false }
        isLocked = false
        return true
    }

    func lockIfNeeded() {
        guard hasPIN else { return }
        isLocked = true
    }

    func unlockWithBiometricsIfPossible() {
        guard isLocked, hasPIN, useBiometrics else { return }
        Task {
            if await authenticateWithBiometrics() {
                isLocked = false
            }
        }
    }

    func enableBiometrics() async {
        useBiometrics = await authenticateWithBiometrics(
            reason: "Подтвердите вход в приложение".appLocalized
        )
    }

    func authenticateInitialBiometrics() async -> Bool {
        await authenticateWithBiometrics(
            reason: "Подтвердите подключение биометрического входа".appLocalized
        )
    }

    func disableBiometrics() {
        useBiometrics = false
    }

    func resetSecurity() {
        PINKeychain.delete()
        hasPIN = false
        isLocked = false
        useBiometrics = false
    }

    private func authenticateWithBiometrics(reason: String? = nil) async -> Bool {
        guard isBiometricsAvailable, !isAuthenticatingBiometrics else { return false }
        isAuthenticatingBiometrics = true
        defer { isAuthenticatingBiometrics = false }

        let context = LAContext()
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason ?? "Подтвердите вход в приложение".appLocalized
            )
        } catch {
            return false
        }
    }
}

private enum PINKeychain {
    private static let service = "finance-app"
    private static let account = "application-pin"

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ pin: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(pin.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
