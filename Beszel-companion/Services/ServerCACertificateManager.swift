import Foundation
import Security
import OSLog

struct ServerCACertificatePayload {
    let certificate: SecCertificate
    let certData: Data
}

/// Stores and loads a per-instance Certificate Authority used to validate the
/// server's TLS certificate. This lets the app trust instances whose
/// certificate is signed by a private/self-signed CA that iOS does not trust
/// out of the box.
struct ServerCACertificateManager {
    nonisolated private static let logger = Logger(subsystem: "com.nohitdev.Beszel", category: "ServerCACertificateManager")
    nonisolated private static let service = "com.nohitdev.Beszel.serverca"

    enum CAError: LocalizedError {
        case invalidCertificate
        case keychainStoreFailed

        var errorDescription: String? {
            switch self {
            case .invalidCertificate: return String(localized: "mtls.error.invalidCertificate")
            case .keychainStoreFailed: return String(localized: "mtls.error.keychainStoreFailed")
            }
        }
    }

    /// Parses DER- or PEM-encoded certificate data into a `SecCertificate`.
    nonisolated static func parseCertificate(from data: Data) -> SecCertificate? {
        if let cert = SecCertificateCreateWithData(nil, data as CFData) {
            return cert
        }
        guard let pem = String(data: data, encoding: .utf8) else { return nil }
        return parsePEMCertificate(pem)
    }

    private nonisolated static func parsePEMCertificate(_ pem: String) -> SecCertificate? {
        let begin = "-----BEGIN CERTIFICATE-----"
        let end = "-----END CERTIFICATE-----"
        guard let beginRange = pem.range(of: begin),
              let endRange = pem.range(of: end, range: beginRange.upperBound..<pem.endIndex) else {
            return nil
        }
        let base64 = pem[beginRange.upperBound..<endRange.lowerBound]
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        guard let der = Data(base64Encoded: base64) else { return nil }
        return SecCertificateCreateWithData(nil, der as CFData)
    }

    /// Validates the supplied certificate file, then persists its normalized DER form.
    nonisolated static func importAndStore(certData: Data, for instanceId: UUID) throws {
        guard let cert = parseCertificate(from: certData) else {
            throw CAError.invalidCertificate
        }
        let der = SecCertificateCopyData(cert) as Data
        try store(derData: der, for: instanceId)
    }

    nonisolated static func store(payload: ServerCACertificatePayload, for instanceId: UUID) throws {
        try store(derData: payload.certData, for: instanceId)
    }

    nonisolated static func store(derData: Data, for instanceId: UUID) throws {
        delete(for: instanceId)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: instanceId.uuidString,
            kSecValueData as String: derData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Failed to store CA cert in keychain: \(status)")
            throw CAError.keychainStoreFailed
        }
    }

    nonisolated static func loadData(for instanceId: UUID) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: instanceId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return data
    }

    nonisolated static func loadCertificate(for instanceId: UUID) -> SecCertificate? {
        guard let der = loadData(for: instanceId) else { return nil }
        return SecCertificateCreateWithData(nil, der as CFData)
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
        guard let cert = loadCertificate(for: instanceId) else { return nil }
        return SecCertificateCopySubjectSummary(cert) as String?
    }
}
