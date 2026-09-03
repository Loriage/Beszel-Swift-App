import SwiftUI

struct RootView: View {
    let languageManager: LanguageManager
    let settingsManager: SettingsManager
    let dashboardManager: DashboardManager
    let instanceManager: InstanceManager
    let alertManager: AlertManager

    @State private var isShowingSettings = false

    private var isLoadingStateForcedForUITesting: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--ui-testing-loading-systems")
#else
        false
#endif
    }

    var body: some View {
        Group {
            if instanceManager.instances.isEmpty && !isLoadingStateForcedForUITesting {
                OnboardingView { name, url, email, password, advanced in
                    instanceManager.addInstance(name: name, url: url, email: email, password: password, clientCert: advanced.clientCert, caCert: advanced.caCert, customHeaders: advanced.customHeaders, fallbackURL: advanced.fallbackURL)
                }
            } else if let activeInstance = instanceManager.activeInstance {
                if instanceManager.isLoadingSystems || isLoadingStateForcedForUITesting {
                    RootLoadingView {
                        isShowingSettings = true
                    }
                } else if let error = instanceManager.loadError {
                    errorView(error: error)
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
                RootLoadingView {
                    isShowingSettings = true
                }
            }
        }
        .environment(\.locale, Locale(identifier: languageManager.currentLanguageCode))
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .environment(dashboardManager)
                .environment(settingsManager)
                .environment(languageManager)
                .environment(instanceManager)
                .environment(alertManager)
        }
        .task(id: instanceManager.systemsLoadRequestID) {
            guard let instance = instanceManager.activeInstance else { return }
            await instanceManager.fetchSystemsForInstance(instance)
        }
        .onChange(of: instanceManager.activeInstanceID) {
            alertManager.pendingAlertDetail = nil
        }
    }

    @ViewBuilder
    private func errorView(error: Error) -> some View {
        NavigationStack {
            MonitoringStateView(state: .failure(MonitoringErrorMessage.message(for: error))) {
                instanceManager.requestSystemsReload()
            }
            .monitoringScreenBackground()
            .navigationTitle("common.error.fetchFailed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("settings.title")
                }
            }
        }
    }
}

private struct RootLoadingView: View {
    let onSettingsTap: () -> Void

    var body: some View {
        NavigationStack {
            MonitoringStateView(state: .loading("systems.loading"))
                .monitoringScreenBackground()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: onSettingsTap) {
                            Image(systemName: "gearshape.fill")
                        }
                        .accessibilityLabel("settings.title")
                        .accessibilityIdentifier("root.loading.settings")
                    }
                }
        }
    }
}
