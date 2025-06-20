//
//  KeychainHelper.swift
//  Beszel-companion
//
//  Created by Bruno DURAND on 20/06/2025.
//

import Foundation
import Security

struct KeychainHelper {
    static func save(data: Data, service: String, account: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data
        ] as CFDictionary

        SecItemDelete(query)
        SecItemAdd(query, nil)
    }

    static func load(service: String, account: String) -> Data? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary

        var result: AnyObject?
        SecItemCopyMatching(query, &result)
        return result as? Data
    }

    static func delete(service: String, account: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary
        SecItemDelete(query)
    }
}
