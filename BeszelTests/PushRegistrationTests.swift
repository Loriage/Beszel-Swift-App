import CryptoKit
import Foundation
import Testing
@testable import Beszel

@MainActor
struct PushRegistrationTests {
    @Test func registrationIncludesHubNameAndExistingAuthenticationFields() async throws {
        let recorder = RegistrationRecorder()
        let service = PushNotificationService { try await recorder.send($0) }
        let instance = hub(name: "Maison été 東京")
        await service.setDeviceToken("test-token")
        await service.registerDevice(for: instance)

        let request = try #require(await recorder.requests.first)
        #expect(request.url?.absoluteString == "https://worker.invalid/register")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try payload(request)
        #expect(body["hubName"] as? String == instance.name)
        #expect(body["instanceId"] as? String == instance.id.uuidString)
        #expect(body["deviceToken"] as? String == "test-token")
        let timestamp = try #require(body["timestamp"] as? Int)
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data("\(timestamp):\(instance.id.uuidString)".utf8),
            using: SymmetricKey(data: Data("test-secret".utf8))
        ).map { String(format: "%02x", $0) }.joined()
        #expect(body["signature"] as? String == signature)
    }

    @Test func registersEveryConfiguredHubAndSkipsIncompleteSettings() async throws {
        let recorder = RegistrationRecorder()
        let service = PushNotificationService { try await recorder.send($0) }
        let first = hub(name: "Maison")
        let second = hub(name: "Bureau")
        var noWorker = hub(name: "No worker")
        noWorker.notifyWorkerURL = nil
        var noSecret = hub(name: "No secret")
        noSecret.notifyWebhookSecret = nil
        let instances = [first, noWorker, second, noSecret]

        await service.registerDevices(for: instances)
        #expect(await recorder.requests.isEmpty)
        await service.setDeviceToken("test-token")
        await service.registerDevices(for: instances)
        let requests = await recorder.requests
        #expect(requests.count == 2)
        #expect(try requests.map { try payload($0)["hubName"] as? String } == ["Maison", "Bureau"])
    }

    @Test func renamedHubKeepsItsRegistrationIdentity() async throws {
        let recorder = RegistrationRecorder()
        let service = PushNotificationService { try await recorder.send($0) }
        var instance = hub(name: "Old name")
        await service.setDeviceToken("test-token")
        await service.registerDevices(for: [instance])
        instance.name = "New name"
        await service.registerDevices(for: [instance])
        let requests = await recorder.requests
        #expect(requests.count == 2)
        let bodies = try requests.map(payload)
        #expect(bodies.first?["hubName"] as? String == "Old name")
        #expect(bodies.last?["hubName"] as? String == "New name")
        #expect(bodies.allSatisfy { $0["instanceId"] as? String == instance.id.uuidString })
    }

    @Test func failedWorkerDoesNotPreventOtherHubRegistrations() async throws {
        let recorder = RegistrationRecorder(failingHost: "unavailable.invalid")
        let service = PushNotificationService { try await recorder.send($0) }
        var first = hub(name: "First")
        first.notifyWorkerURL = "https://unavailable.invalid"
        let second = hub(name: "Second")
        await service.setDeviceToken("test-token")
        await service.registerDevices(for: [first, second])
        let requests = await recorder.requests
        #expect(requests.map { $0.url?.host } == ["unavailable.invalid", "worker.invalid"])
    }

    @Test func tokenRotationKeepsTheHubName() async throws {
        let recorder = RegistrationRecorder()
        let service = PushNotificationService { try await recorder.send($0) }
        let instance = hub(name: "Maison")
        await service.setDeviceToken("old-token")
        await service.registerDevices(for: [instance])
        await service.setDeviceToken("new-token")
        await service.registerDevices(for: [instance])
        let request = try #require(await recorder.requests.last)
        let body = try payload(request)
        #expect(body["deviceToken"] as? String == "new-token")
        #expect(body["hubName"] as? String == "Maison")
    }

    private func hub(name: String) -> Instance {
        Instance(id: UUID(), name: name, url: "https://hub.invalid", email: "test@example.invalid",
                 notifyWorkerURL: "https://worker.invalid/", notifyWebhookSecret: "test-secret")
    }

    private func payload(_ request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private actor RegistrationRecorder {
    private(set) var requests: [URLRequest] = []
    let failingHost: String?

    init(failingHost: String? = nil) { self.failingHost = failingHost }

    func send(_ request: URLRequest) throws -> (Data, URLResponse) {
        requests.append(request)
        if request.url?.host == failingHost { throw URLError(.cannotConnectToHost) }
        return (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
