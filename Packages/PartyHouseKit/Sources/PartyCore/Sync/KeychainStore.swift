import Foundation
import Security

/// Stores secrets (Hue application keys, Home Assistant tokens) in the keychain.
/// Items are marked synchronizable so iCloud Keychain carries them between the
/// user's iPhone and Mac, and placed in the shared access group so the widget
/// extension can read them.
public enum KeychainStore {
    public static let service = "io.github.yennster.partyhouse"
    public static let sharedAccessGroupSuffix = "io.github.yennster.partyhouse.shared"

    public enum Key: String, CaseIterable {
        case hueApplicationKey = "hue.application-key"
        case homeAssistantToken = "ha.token"
    }

    public static func save(_ value: String, for key: Key, account: String = "default") {
        let data = Data(value.utf8)
        let identifier = "\(key.rawValue).\(account)"

        delete(key, account: account)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        var status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecMissingEntitlement || status == errSecParam {
            // Unsigned/dev builds without the synchronizable entitlement still work,
            // just without cross-device sync.
            query[kSecAttrSynchronizable as String] = false
            status = SecItemAdd(query as CFDictionary, nil)
        }
        if status != errSecSuccess {
            NSLog("KeychainStore: save failed for \(identifier) (status \(status))")
        }
    }

    public static func read(_ key: Key, account: String = "default") -> String? {
        let identifier = "\(key.rawValue).\(account)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identifier,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func delete(_ key: Key, account: String = "default") {
        let identifier = "\(key.rawValue).\(account)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identifier,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
