import SwiftUI

struct RootView: View {
    let languageManager: LanguageManager
    let settingsManager: SettingsManager
    let dashboardManager: DashboardManager
    let instanceManager: InstanceManager
    let alertManager: AlertManager

    var body: some View {
        Group {
            if instanceManager.instances.isEmpty {
                OnboardingView { name, url, email, password in
                    instanceManager.addInstance(name: name, url: url, email: email, password: password)
                }
            } else if let activeInstance = instanceManager.activeInstance {
                if instanceManager.isLoadingSystems {
                    VStack { ProgressView("systems.loading") }
                } else if let error = instanceManager.loadError {
                    errorView(error: error, instance: activeInstance)
                } else {
                    MainView(
                        instance: activeInstance,
                        instanceManager: instanceManager,
                        settingsManager: settingsManager,
                        dashboardManager: dashboardManager,
                        languageManager: languageManager,
                        alertManager: alertManager
                    )
                    .id("\(activeInstance.id.uuidString)-\(languageManager.currentLanguageCode)")
                }
            } else {
                ProgressView()
            }
        }
        .environment(\.locale, Locale(identifier: languageManager.currentLanguageCode))
        .onChange(of: instanceManager.activeInstanceID) {
            alertManager.pendingAlertDetail = nil
        }
    }

    @ViewBuilder
    private func errorView(error: Error, instance: Instance) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("common.error.fetchFailed")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                instanceManager.clearError()
                instanceManager.fetchSystemsForInstance(instance)
            } label: {
                Label("common.retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
