import SwiftUI

@main
struct Beszel_companionApp: App {
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var dashboardManager = DashboardManager.shared
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var refreshManager = RefreshManager()
    @StateObject private var instanceManager = InstanceManager.shared

    var body: some Scene {
        WindowGroup {
            RootView(
                languageManager: languageManager,
                settingsManager: settingsManager,
                dashboardManager: dashboardManager,
                refreshManager: refreshManager,
                instanceManager: instanceManager
            )
        }
    }
}
