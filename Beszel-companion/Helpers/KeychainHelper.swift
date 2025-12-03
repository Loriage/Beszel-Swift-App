import Foundation
import Security

struct KeychainHelper {
    nonisolated private static var accessGroup: String {
        return "group.com.nohitdev.Beszel"
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
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
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
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
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
        
        SecItemDelete(query as CFDictionary)
    }
}
