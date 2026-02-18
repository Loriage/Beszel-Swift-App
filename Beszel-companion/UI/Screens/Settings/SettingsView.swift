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
    @State private var isShowingResetAlert = false
    @State private var isAddingInstance = false
    @State private var editingInstance: Instance?
    @State private var isShowingShareSheet = false
    @State private var isAuthenticating = false
    
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
    
    private static let appStoreURL = URL(string: "https://apps.apple.com/us/app/beszel/id6747600765")!
    private static let reviewURL = URL(string: "https://apps.apple.com/app/id6747600765?action=write-review")!
    private static let fallbackGitHubURL = URL(string: "https://github.com/Loriage/Beszel-Swift-App/issues")!
    private static let crowdinURL = URL(string: "https://crowdin.com/project/beszel-swift-app")!

    private var bugReportGitHubURL: URL {
        var components = URLComponents(string: "https://github.com/Loriage/Beszel-Swift-App/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: "[Bug] "),
            URLQueryItem(name: "body", value: bugReportTemplate)
        ]
        return components?.url ?? Self.fallbackGitHubURL
    }
    
    var body: some View {
        @Bindable var bindableLanguageManager = languageManager
        @Bindable var bindableSettingsManager = settingsManager
        
        NavigationStack {
            Form {
                Section(header: Text("settings.instances.title")) {
                    ForEach(instanceManager.instances) { instance in
                        HStack {
                            Text(instance.name)
                            Spacer()
                            if instance.id == instanceManager.activeInstance?.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            instanceManager.setActiveInstance(instance)
                            WidgetCenter.shared.reloadTimelines(ofKind: "BeszelWidget")
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                instanceManager.deleteInstance(instance)
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }

                            Button {
                                editingInstance = instance
                            } label: {
                                Label("common.edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }

                    Button("settings.instances.add") {
                        isAddingInstance = true
                    }
                }
                
                Section(header: Text("settings.title")) {
                    Picker(selection: $bindableLanguageManager.currentLanguageCode) {
                        ForEach(languageManager.availableLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    } label: {
                        Label("settings.display.language", systemImage: "globe")
                            .foregroundStyle(.primary)
                    }
                    .onChange(of: languageManager.currentLanguageCode) {
                        WidgetCenter.shared.reloadTimelines(ofKind: "BeszelWidget")
                    }

                    Picker(selection: $bindableSettingsManager.selectedTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(LocalizedStringKey(theme.rawValue)).tag(theme)
                        }
                    } label: {
                        Label("settings.display.theme", systemImage: "circle.lefthalf.filled")
                            .foregroundStyle(.primary)
                    }

                    Picker(selection: $bindableSettingsManager.selectedTimeRange) {
                        ForEach(TimeRangeOption.allCases) { option in
                            Text(LocalizedStringKey(option.rawValue)).tag(option)
                        }
                    } label: {
                        Label("settings.display.chartPeriod", systemImage: "chart.xyaxis.line")
                            .foregroundStyle(.primary)
                    }
                    .onChange(of: settingsManager.selectedTimeRange) {
                        WidgetCenter.shared.reloadTimelines(ofKind: "BeszelWidget")
                    }

                    Toggle(isOn: Binding(
                        get: { settingsManager.appLockEnabled },
                        set: { newValue in
                            if newValue {
                                isAuthenticating = true
                                Task {
                                    let success = await settingsManager.authenticateWithBiometrics()
                                    if success {
                                        settingsManager.appLockEnabled = true
                                    }
                                    isAuthenticating = false
                                }
                            } else {
                                settingsManager.appLockEnabled = false
                            }
                        }
                    )) {
                        Label("settings.security.appLock", systemImage: "faceid")
                            .foregroundStyle(.primary)
                    }
                    .disabled(isAuthenticating)

                    NavigationLink {
                        NotificationSettingsView()
                            .environment(instanceManager)
                            .environment(alertManager)
                    } label: {
                        HStack {
                            Label("settings.notifications.configuration", systemImage: "bell")
                                .foregroundStyle(.primary)
                            Spacer()
                            if alertManager.notificationsEnabled {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }

                aboutSection
                applicationSection
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
            .alert("settings.application.resetAll.alert.title", isPresented: $isShowingResetAlert) {
                Button("common.cancel", role: .cancel) { }
                Button("settings.application.resetAll.alert.confirm", role: .destructive) {
                    resetAllSettings()
                }
            } message: {
                Text("settings.application.resetAll.alert.message")
            }
            .sheet(isPresented: $isShowingShareSheet) {
                ShareSheet(items: [Self.appStoreURL])
            }
            .sheet(item: $editingInstance) { instance in
                OnboardingView(
                    editingInstance: instance,
                    onComplete: { name, url, email, password in
                        instanceManager.updateInstance(instance, name: name, url: url, email: email, password: password)
                        WidgetCenter.shared.reloadTimelines(ofKind: "BeszelWidget")
                        editingInstance = nil
                    }
                )
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Button {
                isShowingShareSheet = true
            } label: {
                Label("settings.about.share", systemImage: "square.and.arrow.up")
            }
            .foregroundStyle(.primary)

            Link(destination: Self.reviewURL) {
                Label("settings.about.review", systemImage: "star.fill")
            }
            .foregroundStyle(.primary)

            Link(destination: bugReportGitHubURL) {
                Label("settings.about.reportIssue", systemImage: "exclamationmark.bubble")
            }
            .foregroundStyle(.primary)

            Link(destination: Self.crowdinURL) {
                Label("settings.about.translate", systemImage: "globe.europe.africa")
            }
            .foregroundStyle(.primary)
        } header: {
            Text("settings.about")
        }
    }

    private var applicationSection: some View {
        Section {
            Button("settings.dashboard.clearPins", role: .destructive) {
                isShowingClearPinsAlert = true
            }
            .disabled(!dashboardManager.hasPinsForActiveInstance())

            Button("settings.application.resetAll", role: .destructive) {
                isShowingResetAlert = true
            }
        } header: {
            Text("settings.application")
        } footer: {
            Text("Version \(appVersion)")
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    private func resetAllSettings() {
        let suite = UserDefaults.sharedSuite

        // Delete all instance credentials
        for instance in instanceManager.instances {
            instanceManager.deleteInstance(instance)
        }

        // Settings
        suite.removeObject(forKey: "selectedTheme")
        suite.removeObject(forKey: "selectedTimeRange")
        suite.removeObject(forKey: "selectedLanguage")
        suite.removeObject(forKey: "pinnedItemsByInstance")
        suite.removeObject(forKey: "appLockEnabled")

        // Notifications
        suite.removeObject(forKey: "alertsLastCheckedTimestamp")
        suite.removeObject(forKey: "seenAlertHistoryIDs")
        suite.removeObject(forKey: "mutedAlertIDs")
        suite.removeObject(forKey: "alertNotificationsEnabled")

        // Instances
        suite.removeObject(forKey: "instances")
        suite.removeObject(forKey: "activeInstanceID")
        suite.removeObject(forKey: "activeSystemID")

        WidgetCenter.shared.reloadTimelines(ofKind: "BeszelWidget")
        dismiss()
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
