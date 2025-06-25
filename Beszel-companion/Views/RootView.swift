import SwiftUI

struct RootView: View {
    @ObservedObject var languageManager: LanguageManager
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var dashboardManager: DashboardManager
    @ObservedObject var refreshManager: RefreshManager
    
    @State private var isShowingSettings = false
    
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted = false

    var body: some View {
        Group {
            if isOnboardingCompleted {
                let creds = CredentialsManager.shared.loadCredentials()
                if let url = creds.url, let email = creds.email, let password = creds.password {
                    MainView(
                        apiService: BeszelAPIService(url: url, email: email, password: password),
                        refreshManager: refreshManager,
                        onLogout: logout,
                        isShowingSettings: $isShowingSettings,
                    )
                    .id(languageManager.currentLanguageCode)
                } else {
                    OnboardingView(onComplete: completeOnboarding)
                }
            } else {
                OnboardingView(onComplete: completeOnboarding)
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(onLogout: logout)
        }
        .environmentObject(settingsManager)
        .environmentObject(dashboardManager)
        .environmentObject(languageManager)
        .environment(\.locale, Locale(identifier: languageManager.currentLanguageCode))
    }

    private func completeOnboarding() {
        isOnboardingCompleted = true
    }

    private func logout() {
        dashboardManager.removeAllPins()
        CredentialsManager.shared.deleteCredentials()
        CredentialsManager.shared.setOnboardingCompleted(false)
    }
}
