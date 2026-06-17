import Foundation
import Security
import OSLog

/// Stores per-instance custom HTTP headers (e.g. Cloudflare Access
/// `CF-Access-Client-Id` / `CF-Access-Client-Secret`) in the keychain, since
/// the values are typically secrets. Headers are applied to every request the
/// app and widget make to that instance.
struct CustomHeadersManager {
    nonisolated private static let logger = Logger(subsystem: "com.nohitdev.Beszel", category: "CustomHeadersManager")
    nonisolated private static let service = "com.nohitdev.Beszel.headers"

    nonisolated static func store(_ headers: [String: String], for instanceId: UUID) {
        delete(for: instanceId)
        let trimmed = headers.filter { !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !trimmed.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: trimmed) else { return }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: instanceId.uuidString,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Failed to store custom headers in keychain: \(status)")
        }
    }

    nonisolated static func load(for instanceId: UUID) -> [String: String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: instanceId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return [:] }
        return dict
    }

    nonisolated static func delete(for instanceId: UUID) {
        SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: instanceId.uuidString
        ] as CFDictionary)
    }

    nonisolated static func hasHeaders(for instanceId: UUID) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: instanceId.uuidString,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
}
