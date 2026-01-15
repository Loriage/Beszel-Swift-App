import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(DashboardManager.self) var dashboardManager
    @Environment(SettingsManager.self) var settingsManager
    @Environment(LanguageManager.self) var languageManager
    @Environment(InstanceManager.self) var instanceManager
    @Environment(AlertManager.self) var alertManager
    
    @Environment(\.dismiss) var dismiss
    
    @State private var isShowingClearPinsAlert = false
    @State private var isAddingInstance = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    private var bugReportTemplate: String {
        """
        ## Bug Description
        <!-- Describe the bug clearly and concisely -->


        ## Steps to Reproduce
        1.
        2.
        3.

        ## Expected Behavior
        <!-- What did you expect to happen? -->


        ## Actual Behavior
        <!-- What actually happened? -->


        ## Screenshots
        <!-- If applicable, add screenshots to help explain the issue -->


        ## Device Information
        - App Version: \(appVersion)
        - iOS Version: \(UIDevice.current.systemVersion)
        - Device: \(UIDevice.current.model)
        """
    }

    private static let fallbackGitHubURL = URL(string: "https://github.com/Loriage/Beszel-Swift-App/issues")!
    private static let fallbackEmailURL = URL(string: "mailto:contact@nohit.dev")!

    private var bugReportGitHubURL: URL {
        var components = URLComponents(string: "https://github.com/Loriage/Beszel-Swift-App/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: "[Bug] "),
            URLQueryItem(name: "body", value: bugReportTemplate)
        ]
        return components?.url ?? Self.fallbackGitHubURL
    }

    private var bugReportEmailURL: URL {
        var components = URLComponents(string: "mailto:contact@nohit.dev")
        components?.queryItems = [
            URLQueryItem(name: "subject", value: "[Bug Report] Beszel Companion"),
            URLQueryItem(name: "body", value: bugReportTemplate)
        ]
        return components?.url ?? Self.fallbackEmailURL
    }

    var body: some View {
        @Bindable var bindableLanguageManager = languageManager
        @Bindable var bindableSettingsManager = settingsManager
        
        NavigationStack {
            Form {
                Section(header: Text("settings.display")) {
                    Picker("settings.display.language", selection: $bindableLanguageManager.currentLanguageCode) {
                        ForEach(languageManager.availableLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .onChange(of: languageManager.currentLanguageCode) {
                        WidgetCenter.shared.reloadTimelines(ofKind: "BeszelWidget")
                    }
                    
                    Picker("settings.display.chartPeriod", selection: $bindableSettingsManager.selectedTimeRange) {
                        ForEach(TimeRangeOption.allCases) { option in
                            Text(LocalizedStringKey(option.rawValue)).tag(option)
                        }
                    }
                    .onChange(of: settingsManager.selectedTimeRange) {
                        WidgetCenter.shared.reloadTimelines(ofKind: "BeszelWidget")
                    }
                }
                
                Section(header: Text("settings.instances.title")) {
                    ForEach(instanceManager.instances) { instance in
                        HStack {
                            Image(systemName: "server.rack")
                            Text(instance.name)
                            Spacer()
                            if instance.id == instanceManager.activeInstance?.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            instanceManager.setActiveInstance(instance)
                            WidgetCenter.shared.reloadTimelines(ofKind: "BeszelWidget")
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { instanceManager.instances[$0] }.forEach(instanceManager.deleteInstance)
                    }
                    
                    Button("settings.instances.add") {
                        isAddingInstance = true
                    }
                }
                
                Section(header: Text("settings.notifications")) {
                    @Bindable var bindableAlertManager = alertManager
                    Toggle("settings.notifications.enabled", isOn: $bindableAlertManager.notificationsEnabled)
                        .onChange(of: alertManager.notificationsEnabled) { _, newValue in
                            if newValue {
                                BackgroundAlertChecker.shared.scheduleBackgroundTask()
                            } else {
                                BackgroundAlertChecker.shared.cancelScheduledTask()
                            }
                        }

                    NavigationLink {
                        AlertHistoryView()
                            .environment(instanceManager)
                            .environment(alertManager)
                            .navigationTitle("settings.notifications.history")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label("settings.notifications.history", systemImage: "bell")
                    }

                    NavigationLink {
                        ConfiguredAlertsView()
                            .environment(instanceManager)
                            .environment(alertManager)
                            .navigationTitle("settings.notifications.configured")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label("settings.notifications.configured", systemImage: "bell.badge")
                    }
                }

                Section(header: Text("settings.dashboard")) {
                    Button("settings.dashboard.clearPins", role: .destructive) {
                        isShowingClearPinsAlert = true
                    }
                    .disabled(!dashboardManager.hasPinsForActiveInstance())
                }

                Section(header: Text("settings.support")) {
                    Link(destination: bugReportGitHubURL) {
                        HStack {
                            Image(systemName: "ant")
                            Text("settings.support.reportBug.github")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: bugReportEmailURL) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("settings.support.reportBug.email")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationDestination(for: AlertDetail.self) { alert in
                AlertDetailView(alert: alert)
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $isAddingInstance) {
                OnboardingView { name, url, email, password in
                    instanceManager.addInstance(name: name, url: url, email: email, password: password)
                    isAddingInstance = false
                }
            }
            .alert("settings.dashboard.clearPins.alert.title", isPresented: $isShowingClearPinsAlert) {
                Button("common.cancel", role: .cancel) { }
                Button("common.delete", role: .destructive) {
                    dashboardManager.nukeAllPins()
                }
            } message: {
                Text("settings.dashboard.clearPins.alert.message")
            }
        }
    }
}
