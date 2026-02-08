import SwiftUI
import UserNotifications
import os

private let logger = Logger(subsystem: "com.nohitdev.Beszel", category: "AppDelegate")

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        logger.info("Received APNs device token: \(token.prefix(8))...")

        Task { @MainActor in
            await PushNotificationService.shared.setDeviceToken(token)
            if let instance = InstanceManager.shared.activeInstance {
                await PushNotificationService.shared.registerDevice(for: instance)
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        logger.info("Received remote notification")

        if let alertDetail = AlertDetail(userInfo: userInfo) {
            Task { @MainActor in
                AlertManager.shared.pendingAlertDetail = alertDetail
            }
        }

        completionHandler(.newData)
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
    private let dashboardManager = DashboardManager.shared
    @State private var languageManager = LanguageManager()
    private let instanceManager = InstanceManager.shared
    private let alertManager = AlertManager.shared

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
                    Task {
                        await PushNotificationService.shared.requestNotificationPermission()
                    }
                }
            }
        }
    }
}
