import Foundation

enum NotificationSecretManager {
    nonisolated private static let service = "com.nohitdev.Beszel.notification-secret"

    nonisolated static func store(_ secret: String, for instanceID: UUID) -> Bool {
        guard let data = secret.data(using: .utf8), !data.isEmpty else {
            delete(for: instanceID)
            return true
        }
        return KeychainHelper.save(
            data: data,
            service: service,
            account: instanceID.uuidString,
            useSharedKeychain: true
        )
    }

    nonisolated static func load(for instanceID: UUID) -> String? {
        guard let data = KeychainHelper.load(
            service: service,
            account: instanceID.uuidString,
            useSharedKeychain: true
        ) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    nonisolated static func delete(for instanceID: UUID) {
        KeychainHelper.delete(
            service: service,
            account: instanceID.uuidString,
            useSharedKeychain: true
        )
    }
}
