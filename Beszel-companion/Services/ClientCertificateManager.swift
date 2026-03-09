import Foundation
import Security
import OSLog

/// Payload carrying both the live SecIdentity (for in-session mTLS) and the raw P12 data
/// needed to persist the certificate across instances.
struct ClientCertificatePayload {
    let identity: SecIdentity
    let p12Data: Data
    let password: String
}

struct ClientCertificateManager {
    nonisolated private static let logger = Logger(subsystem: "com.nohitdev.Beszel", category: "ClientCertificateManager")
    nonisolated private static let service = "com.nohitdev.Beszel.mtls"

    enum MTLSError: LocalizedError {
        case importFailed
        case invalidPasswordOrFile
        case keychainStoreFailed

        var errorDescription: String? {
            switch self {
            case .importFailed: return String(localized: "mtls.error.importFailed")
            case .invalidPasswordOrFile: return String(localized: "mtls.error.invalidPasswordOrFile")
            case .keychainStoreFailed: return String(localized: "mtls.error.keychainStoreFailed")
            }
        }
    }

    // MARK: - P12 storage (kSecClassGenericPassword — one slot per instance, no shared-key conflicts)

    private nonisolated static func encodePayload(p12Data: Data, password: String) -> Data? {
        let dict: [String: Any] = ["p12": p12Data.base64EncodedString(), "pw": password]
        return try? JSONSerialization.data(withJSONObject: dict)
    }

    private nonisolated static func decodePayload(_ data: Data) -> (p12Data: Data, password: String)? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let p12Base64 = dict["p12"],
              let p12Data = Data(base64Encoded: p12Base64),
              let password = dict["pw"]
        else { return nil }
        return (p12Data, password)
    }

    /// Import a PKCS#12 file and store it in the keychain for the given instance.
    nonisolated static func importAndStore(p12Data: Data, password: String, for instanceId: UUID) throws {
        _ = try importIdentity(from: p12Data, password: password) // validate before storing
        try store(p12Data: p12Data, password: password, for: instanceId)
    }

    nonisolated static func store(p12Data: Data, password: String, for instanceId: UUID) throws {
        delete(for: instanceId)
        guard let data = encodePayload(p12Data: p12Data, password: password) else {
            throw MTLSError.keychainStoreFailed
        }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: instanceId.uuidString,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Failed to store mTLS cert in keychain: \(status)")
            throw MTLSError.keychainStoreFailed
        }
    }

    nonisolated static func loadIdentity(for instanceId: UUID) -> SecIdentity? {
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
              let (p12Data, password) = decodePayload(data),
              let identity = try? importIdentity(from: p12Data, password: password)
        else { return nil }
        return identity
    }

    nonisolated static func delete(for instanceId: UUID) {
        SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: instanceId.uuidString
        ] as CFDictionary)
    }

    nonisolated static func hasCertificate(for instanceId: UUID) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: instanceId.uuidString,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    nonisolated static func certificateSubject(for instanceId: UUID) -> String? {
        guard let identity = loadIdentity(for: instanceId) else { return nil }
        var cert: SecCertificate?
        SecIdentityCopyCertificate(identity, &cert)
        guard let certificate = cert else { return nil }
        return SecCertificateCopySubjectSummary(certificate) as String?
    }

    // MARK: - Import helper (no keychain storage)

    /// Import a PKCS#12 file and return the identity without storing it.
    nonisolated static func importIdentity(from p12Data: Data, password: String) throws -> SecIdentity {
        var items: CFArray?
        let options = [kSecImportExportPassphrase as String: password] as CFDictionary
        let status = SecPKCS12Import(p12Data as CFData, options, &items)

        guard status == errSecSuccess else {
            if status == errSecAuthFailed || status == errSecPkcs12VerifyFailure {
                throw MTLSError.invalidPasswordOrFile
            }
            throw MTLSError.importFailed
        }

        guard let array = items as? [[String: Any]],
              let first = array.first,
              let identityRef = first[kSecImportItemIdentity as String] else {
            throw MTLSError.importFailed
        }
        // SecIdentity is a CF type alias for AnyObject; force cast is correct here.
        let identity = identityRef as! SecIdentity // swiftlint:disable:this force_cast
        return identity
    }
}
