import Foundation
import Testing
@testable import Beszel

@Suite(.serialized)
@MainActor
struct AuthenticationRecoveryTests {
    @Test(arguments: [false, true])
    func expirationDuringRefreshRequiresSignIn(quickRefresh: Bool) async {
        let instance = Instance(id: UUID(), name: "Test", url: "https://hub.invalid", email: "test@example.invalid")
        let suite = "AuthenticationRecoveryTests.\(instance.id)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = InstanceManager(userDefaults: defaults)
        manager.instances = [instance]
        manager.setActiveInstance(instance)
        let api = BeszelAPIService(instance: instance, instanceManager: manager, testToken: "expired") { _ in
            throw URLError(.userAuthenticationRequired)
        }
        let store = BeszelStore(instance: instance, settingsManager: SettingsManager(),
                                dashboardManager: DashboardManager(userDefaults: defaults),
                                instanceManager: manager, apiService: api)
        if quickRefresh {
            await store.refreshLatestStatsOnly()
        } else {
            await store.fetchData()
        }
        #expect(store.authenticationFailed)
        #expect((manager.loadError as? URLError)?.code == .userAuthenticationRequired)
        #expect(!manager.isLoadingSystems)
    }

    @Test func signInKeepsCurrentSettingsAndClearsCachedTokens() throws {
        let instance = Instance(id: UUID(), name: "Original", url: "https://hub.invalid", email: "old@example.invalid",
                                fallbackURL: "https://fallback.invalid", notifyWorkerURL: "https://notify.invalid", notifyWebhookSecret: nil)
        let defaults = UserDefaults(suiteName: "AuthenticationRecoveryTests.\(instance.id)")!
        let manager = InstanceManager(userDefaults: defaults)
        var edited = instance
        edited.name = "Renamed"
        manager.instances = [edited]
        manager.setActiveInstance(edited)
        manager.requireReauthentication(for: instance.id)
        let requestID = manager.systemsLoadRequestID
        let cache = UserDefaults.sharedSuite
        cache.set("expired", forKey: "cachedToken_\(instance.id)")
        cache.set(Date(), forKey: "cachedTokenTime_\(instance.id)")
        CustomHeadersManager.store(["X-Test": "preserved"], for: instance.id)
        defer {
            manager.deleteInstance(edited)
            defaults.removePersistentDomain(forName: "AuthenticationRecoveryTests.\(instance.id)")
        }

        #expect(manager.completeReauthentication(for: instance, email: "new@example.invalid", credential: "eyJ.fixture.new"))
        #expect(manager.activeInstance?.id == instance.id)
        #expect(manager.activeInstance?.name == "Renamed")
        #expect(manager.activeInstance?.email == "new@example.invalid")
        #expect(manager.activeInstance?.fallbackURL == instance.fallbackURL)
        #expect(manager.activeInstance?.notifyWorkerURL == instance.notifyWorkerURL)
        #expect(manager.loadCredential(for: instance) == "eyJ.fixture.new")
        #expect(cache.object(forKey: "cachedToken_\(instance.id)") == nil)
        #expect(cache.object(forKey: "cachedTokenTime_\(instance.id)") == nil)
        #expect(manager.systemsLoadRequestID != requestID)
        #expect(manager.isLoadingSystems && manager.loadError == nil)
        let advanced = InstanceAdvancedOptions.stored(for: edited)
        #expect(advanced.customHeaders == ["X-Test": "preserved"])
        #expect(advanced.fallbackURL == instance.fallbackURL)
    }

    @Test func staleSignInCannotUpdateAnotherOrRemovedInstance() {
        let instance = Instance(id: UUID(), name: "First", url: "https://first.invalid", email: "test@example.invalid")
        let other = Instance(id: UUID(), name: "Second", url: "https://second.invalid", email: "test@example.invalid")
        let defaults = UserDefaults(suiteName: "AuthenticationRecoveryTests.\(instance.id)")!
        let manager = InstanceManager(userDefaults: defaults)
        manager.instances = [instance, other]
        manager.setActiveInstance(other)
        let requestID = manager.systemsLoadRequestID
        #expect(!manager.completeReauthentication(for: instance, email: "new@example.invalid", credential: "new"))
        manager.requireReauthentication(for: instance.id)
        #expect(manager.loadError == nil)
        #expect(manager.activeInstance?.id == other.id)
        #expect(manager.systemsLoadRequestID == requestID)
        manager.instances = []
        #expect(!manager.completeReauthentication(for: other, email: "new@example.invalid", credential: "new"))
        defaults.removePersistentDomain(forName: "AuthenticationRecoveryTests.\(instance.id)")
    }

    @Test func transportFailureDoesNotRequireSignIn() async throws {
        let instance = Instance(id: UUID(), name: "Test", url: "https://hub.invalid", email: "test@example.invalid")
        let defaults = UserDefaults(suiteName: "AuthenticationRecoveryTests.\(instance.id)")!
        let api = BeszelAPIService(instance: instance, instanceManager: InstanceManager(userDefaults: defaults), testToken: "test") { _ in
            throw URLError(.timedOut)
        }
        do {
            _ = try await api.fetchSystems()
            Issue.record("Expected a timeout")
        } catch {
            #expect((error as? URLError)?.code == .timedOut)
        }
    }

    @Test(arguments: [400, 401, 403, 429, 500, 503])
    func refreshFailuresDistinguishExpiredSessionsFromServerErrors(status: Int) async throws {
        let instance = Instance(id: UUID(), name: "Test", url: "https://hub.invalid", email: "test@example.invalid")
        let defaults = UserDefaults(suiteName: "AuthenticationRecoveryTests.\(instance.id)")!
        let manager = InstanceManager(userDefaults: defaults)
        defer { BeszelAPIService.clearCachedAuthentication(for: instance.id) }
        let api = BeszelAPIService(instance: instance, instanceManager: manager, testToken: "expired", testCredential: "eyJ.fixture.expired") { request in
            let code = request.url!.path.hasSuffix("auth-refresh") ? status : 401
            return (Data("{}".utf8), HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!)
        }
        do {
            _ = try await api.fetchSystems()
            Issue.record("Expected the request to fail")
        } catch {
            if [400, 401, 403].contains(status) {
                #expect((error as? URLError)?.code == .userAuthenticationRequired)
            } else if case let BeszelAPIService.BeszelAPIError.httpError(code) = error {
                #expect(code == status)
            } else {
                Issue.record("Server error was treated as an expired session: \(error)")
            }
        }
    }
}
