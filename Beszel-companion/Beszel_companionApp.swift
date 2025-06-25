import SwiftUI

@main
struct Beszel_companionApp: App {
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var dashboardManager = DashboardManager()
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var refreshManager = RefreshManager()

    var body: some Scene {
        WindowGroup {
            RootView(
                languageManager: languageManager,
                settingsManager: settingsManager,
                dashboardManager: dashboardManager,
                refreshManager: refreshManager
            )
        }
    }
}
