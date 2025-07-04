import SwiftUI

struct RootView: View {
    @ObservedObject var languageManager: LanguageManager
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var dashboardManager: DashboardManager
    @ObservedObject var refreshManager: RefreshManager
    @ObservedObject var instanceManager: InstanceManager
    
    @State private var isShowingSettings = false
    @State private var selectedTab: Tab = .home

    var body: some View {
        Group {
            if instanceManager.instances.isEmpty {
                OnboardingView(onComplete: { name, url, email, password in
                    instanceManager.addInstance(name: name, url: url, email: email, password: password)
                })
            } else if let activeInstance = instanceManager.activeInstance {
                if let activeSystem = instanceManager.activeSystem {
                    MainView(
                        instance: activeInstance,
                        instanceManager: instanceManager,
                        settingsManager: settingsManager,
                        refreshManager: refreshManager,
                        isShowingSettings: $isShowingSettings,
                        selectedTab: $selectedTab
                    )
                    .id("\(activeInstance.id.uuidString)-\(activeSystem.id)-\(languageManager.currentLanguageCode)-\(settingsManager.selectedTimeRange.rawValue)")
                } else {
                    VStack {
                        ProgressView("systems.loading")
                    }
                }
            } else {
                ProgressView()
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(instanceManager: instanceManager)
        }
        .environmentObject(settingsManager)
        .environmentObject(dashboardManager)
        .environmentObject(languageManager)
        .environment(\.locale, Locale(identifier: languageManager.currentLanguageCode))
    }
}
