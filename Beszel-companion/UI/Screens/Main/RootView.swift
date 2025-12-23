import SwiftUI

struct RootView: View {
    let languageManager: LanguageManager
    let settingsManager: SettingsManager
    let dashboardManager: DashboardManager
    let instanceManager: InstanceManager
    
    var body: some View {
        Group {
            if instanceManager.instances.isEmpty {
                OnboardingView { name, url, email, password in
                    instanceManager.addInstance(name: name, url: url, email: email, password: password)
                }
            } else if let activeInstance = instanceManager.activeInstance {
                if instanceManager.isLoadingSystems {
                    VStack { ProgressView("systems.loading") }
                } else {
                    MainView(
                        instance: activeInstance,
                        instanceManager: instanceManager,
                        settingsManager: settingsManager,
                        dashboardManager: dashboardManager,
                        languageManager: languageManager
                    )
                    .id("\(activeInstance.id.uuidString)-\(languageManager.currentLanguageCode)")
                }
            } else {
                ProgressView()
            }
        }
        .environment(\.locale, Locale(identifier: languageManager.currentLanguageCode))
    }
}
