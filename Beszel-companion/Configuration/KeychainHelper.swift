import Foundation
import Security
import OSLog

struct KeychainHelper {
    nonisolated private static let logger = Logger(subsystem: "com.nohitdev.Beszel", category: "KeychainHelper")

    nonisolated private static var accessGroup: String {
        return Constants.appGroupId
    }

    nonisolated static func save(data: Data, service: String, account: String, useSharedKeychain: Bool) -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        if useSharedKeychain {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        // Delete existing item first
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            logger.warning("Keychain delete before save failed: \(deleteStatus)")
        }

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            logger.error("Keychain save failed: \(status) for service: \(service, privacy: .public)")
        }

        return status == errSecSuccess
    }

    nonisolated static func load(service: String, account: String, useSharedKeychain: Bool) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if useSharedKeychain {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        case errSecUserCanceled:
            logger.warning("Keychain access was cancelled by user")
            return nil
        case errSecAuthFailed:
            logger.error("Keychain authentication failed for service: \(service, privacy: .public)")
            return nil
        default:
            logger.error("Keychain load failed: \(status) for service: \(service, privacy: .public)")
            return nil
        }
    }

    nonisolated static func delete(service: String, account: String, useSharedKeychain: Bool) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if useSharedKeychain {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.warning("Keychain delete failed: \(status) for service: \(service, privacy: .public)")
        }
    }
}
