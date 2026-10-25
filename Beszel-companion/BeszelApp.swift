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
        logger.info("Received APNs device token")

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

    @State private var isUnlocked = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
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
                    if settingsManager.appLockEnabled {
                        isUnlocked = false
                    }
                    if alertManager.notificationsEnabled {
                        Task {
                            await PushNotificationService.shared.requestNotificationPermission()
                        }
                    }
                }
                if settingsManager.appLockEnabled && !isUnlocked {
                    AppLockView(settingsManager: settingsManager) {
                        isUnlocked = true
                    }
                }
            }
            .environment(\.locale, Locale(identifier: languageManager.currentLanguageCode))
            .onChange(of: settingsManager.selectedTheme, initial: true) { _, theme in
                applyTheme(theme)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    isUnlocked = false
                } else if newPhase == .active {
                    applyTheme(settingsManager.selectedTheme)
                }
            }
        }
    }

    /// `.preferredColorScheme` at the root doesn't reliably update while a sheet (Settings) is presented,
    /// so set the style on the windows, which every presentation inherits.
    private func applyTheme(_ theme: AppTheme) {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = theme.interfaceStyle
            }
        }
    }
}

private struct AppLockView: View {
    let settingsManager: SettingsManager
    let onUnlocked: () -> Void
    @State private var authFailed = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            if authFailed {
                Button {
                    authenticate()
                } label: {
                    Text("settings.security.appLock.retry")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            } else {
                VStack(spacing: MonitoringSpacing.standard) {
                    Image(systemName: "lock.shield.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("settings.security.appLock.required")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .onAppear {
            authenticate()
        }
    }

    private func authenticate() {
        authFailed = false
        Task {
            let success = await settingsManager.authenticateWithBiometrics()
            if success {
                onUnlocked()
            } else {
                authFailed = true
            }
        }
    }
}
