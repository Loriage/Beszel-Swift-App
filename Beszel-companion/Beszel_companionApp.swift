import SwiftUI

@main
struct Beszel_companionApp: App {
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted = false

    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var dashboardManager = DashboardManager()

    var body: some Scene {
        WindowGroup {
            if isOnboardingCompleted {
                let creds = CredentialsManager.shared.loadCredentials()
                if let url = creds.url, let email = creds.email, let password = creds.password {
                    MainView(
                        apiService: BeszelAPIService(url: url, email: email, password: password),
                        onLogout: logout
                    )
                    .environmentObject(settingsManager)
                    .environmentObject(dashboardManager)
                } else {
                    OnboardingView(onComplete: completeOnboarding)
                }
            } else {
                OnboardingView(onComplete: completeOnboarding)
            }
        }
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
