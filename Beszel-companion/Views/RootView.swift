import SwiftUI

struct RootView: View {
    let languageManager: LanguageManager
    let settingsManager: SettingsManager
    let dashboardManager: DashboardManager
    let refreshManager: RefreshManager
    let instanceManager: InstanceManager
    
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
                        languageManager: languageManager,
                        isShowingSettings: $isShowingSettings,
                        selectedTab: $selectedTab
                    )
                    // L'ID force le rafraîchissement complet si l'instance ou la langue change
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
        .environment(\.locale, Locale(identifier: languageManager.currentLanguageCode))
        .onChange(of: refreshManager.refreshSignal) {
             // Trigger global refresh logic if needed handled by views observing dataService
        }
    }
}
