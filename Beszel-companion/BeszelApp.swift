import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            AlertManager.shared.handleNotificationResponse(response)
        }
        completionHandler()
    }
}

@main
struct BeszelApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
