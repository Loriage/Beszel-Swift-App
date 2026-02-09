import Foundation
import UIKit
import CryptoKit
import os

actor PushNotificationService {
    static let shared = PushNotificationService()
    private static let logger = Logger(subsystem: "com.nohitdev.Beszel", category: "PushNotificationService")

    private var deviceToken: String?

    private init() {}

    func setDeviceToken(_ token: String) {
        self.deviceToken = token
        Self.logger.info("Device token set: \(token.prefix(8))...")
    }

    func registerDevice(for instance: Instance) async {
        guard let token = deviceToken else {
            Self.logger.warning("No device token available for registration")
            return
        }

        guard let workerURL = instance.notifyWorkerURL?.trimmingCharacters(in: CharacterSet(charactersIn: "/")),
              !workerURL.isEmpty else {
            Self.logger.info("No worker URL configured for instance \(instance.name)")
            return
        }

        guard let secret = instance.notifyWebhookSecret, !secret.isEmpty else {
            Self.logger.warning("No webhook secret configured for instance \(instance.name)")
            return
        }

        let instanceId = instance.id.uuidString
        let timestamp = Int(Date().timeIntervalSince1970)
        let message = "\(timestamp):\(instanceId)"
        let sig = signature(message, secret: secret)

        let payload: [String: Any] = [
            "deviceToken": token,
            "instanceId": instanceId,
            "timestamp": timestamp,
            "signature": sig
        ]

        guard let url = URL(string: "\(workerURL)/register") else {
            Self.logger.error("Invalid worker URL: \(workerURL)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    Self.logger.info("Device registered successfully with worker for instance \(instance.name)")
                } else {
                    Self.logger.error("Failed to register device: HTTP \(httpResponse.statusCode)")
                }
            }
        } catch {
            Self.logger.error("Failed to register device: \(error.localizedDescription)")
        }
    }

    func generateWebhookURL(for instance: Instance) -> String? {
        guard let workerURL = instance.notifyWorkerURL?.trimmingCharacters(in: CharacterSet(charactersIn: "/")),
              !workerURL.isEmpty else {
            return nil
        }

        guard let secret = instance.notifyWebhookSecret, !secret.isEmpty else {
            return nil
        }

        let instanceId = instance.id.uuidString
        let timestamp = Int(Date().timeIntervalSince1970)
        let message = "\(timestamp):\(instanceId)"
        let sig = signature(message, secret: secret)

        let webhookPath = Data("\(timestamp):\(instanceId):\(sig)".utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        return "generic+\(workerURL)/push/\(webhookPath)?template=json"
    }

    func signature(_ message: String, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        return Data(signature).map { String(format: "%02x", $0) }.joined()
    }

    @MainActor
    func requestNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                Self.logger.info("Notification permission granted: \(granted)")
            } catch {
                Self.logger.error("Failed to request notification permission: \(error.localizedDescription)")
            }
        }

        UIApplication.shared.registerForRemoteNotifications()
    }
}
