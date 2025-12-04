import SwiftUI

@main
struct Beszel_companionApp: App {
    @State private var settingsManager = SettingsManager()
    @State private var dashboardManager = DashboardManager.shared
    @State private var languageManager = LanguageManager()
    @State private var instanceManager = InstanceManager.shared
    
    var body: some Scene {
        WindowGroup {
            RootView(
                languageManager: languageManager,
                settingsManager: settingsManager,
                dashboardManager: dashboardManager,
                instanceManager: instanceManager
            )
            .environment(settingsManager)
            .environment(dashboardManager)
            .environment(languageManager)
            .environment(instanceManager)
        }
    }
}
