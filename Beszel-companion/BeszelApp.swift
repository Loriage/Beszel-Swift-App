import SwiftUI

@main
struct BeszelApp: App {
    @State private var settingsManager = SettingsManager()
    @State private var dashboardManager = DashboardManager.shared
    @State private var languageManager = LanguageManager()
    @State private var instanceManager = InstanceManager.shared
    @State private var alertManager = AlertManager.shared

    init() {
        BackgroundAlertChecker.shared.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                languageManager: languageManager,
                settingsManager: settingsManager,
                dashboardManager: dashboardManager,
                instanceManager: instanceManager,
                alertManager: alertManager
            )
            .environment(settingsManager)
            .environment(dashboardManager)
            .environment(languageManager)
            .environment(instanceManager)
            .environment(alertManager)
            .onAppear {
                if alertManager.notificationsEnabled {
                    BackgroundAlertChecker.shared.scheduleBackgroundTask()
                }
            }
        }
    }
}
