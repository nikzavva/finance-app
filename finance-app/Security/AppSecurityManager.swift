import Combine
import Foundation
import LocalAuthentication
import Security

@MainActor
final class AppSecurityManager: ObservableObject {
    @Published private(set) var isLocked: Bool
    @Published private(set) var hasPIN: Bool
    @Published var useBiometrics: Bool {
        didSet { userDefaults.set(useBiometrics, forKey: Self.biometricsKey) }
    }

    private static let biometricsKey = "use_biometrics"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let hasPIN = PINKeychain.read() != nil
        self.hasPIN = hasPIN
        self.isLocked = hasPIN
        self.useBiometrics = userDefaults.bool(forKey: Self.biometricsKey)
    }

    var biometryName: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Биометрия"
        }
        return switch context.biometryType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        default: "Биометрия"
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
        guard isLocked, hasPIN, useBiometrics, isBiometricsAvailable else { return }
        let context = LAContext()
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Подтвердите вход в приложение"
        ) { [weak self] success, _ in
            guard success else { return }
            DispatchQueue.main.async {
                self?.isLocked = false
            }
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
}
