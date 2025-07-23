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
                OnboardingView(viewModel: OnboardingViewModel(onComplete: { name, url, email, password in
                    instanceManager.addInstance(name: name, url: url, email: email, password: password)
                }))
            } else if let activeInstance = instanceManager.activeInstance {
                if instanceManager.isLoadingSystems {
                    VStack {
                        ProgressView("systems.loading")
                    }
                } else {
                    MainView(
                        instance: activeInstance,
                        instanceManager: instanceManager,
                        settingsManager: settingsManager,
                        refreshManager: refreshManager,
                        dashboardManager: dashboardManager,
                        isShowingSettings: $isShowingSettings,
                        selectedTab: $selectedTab
                    )
                    .id("\(activeInstance.id.uuidString)-\(instanceManager.activeSystem?.id ?? "no-system")-\(languageManager.currentLanguageCode)-\(settingsManager.selectedTimeRange.rawValue)")
                }
            } else {
                ProgressView()
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                dashboardManager: dashboardManager,
                settingsManager: settingsManager,
                languageManager: languageManager,
                instanceManager: instanceManager
            )
        }
        .environmentObject(settingsManager)
        .environmentObject(dashboardManager)
        .environmentObject(languageManager)
        .environmentObject(instanceManager)
        .environment(\.locale, Locale(identifier: languageManager.currentLanguageCode))
    }
}
