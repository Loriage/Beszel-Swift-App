#if DEBUG
import Foundation

@MainActor
enum AuthenticationUITestFixture {
    static func makeManager() -> InstanceManager {
        let suite = "com.nohitdev.Beszel.AuthenticationUITests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let manager = InstanceManager(userDefaults: defaults)
        let unavailable = ProcessInfo.processInfo.arguments.contains("--ui-testing-auth-server-error")
        let instance = Instance(id: UUID(uuidString: "B1E00000-0000-0000-0000-000000000098")!,
                                name: "OIDC test hub", url: "http://127.0.0.1:47898" + (unavailable ? "/unavailable" : ""),
                                email: "test@example.invalid")
        BeszelAPIService.clearCachedAuthentication(for: instance.id)
        manager.instances = [instance]
        manager.updateCredential(for: instance, newCredential: "eyJ.fixture.expired")
        CustomHeadersManager.store(["X-Reauth-Test": "preserved"], for: instance.id)
        manager.setActiveInstance(instance)
        return manager
    }
}
#endif
