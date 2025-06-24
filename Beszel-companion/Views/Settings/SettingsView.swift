import SwiftUI
import WidgetKit

struct SettingsView: View {
    @EnvironmentObject var dashboardManager: DashboardManager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) var dismiss

    var onLogout: () -> Void
    @State private var isShowingLogoutAlert = false
    @State private var isShowingClearPinsAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("settings.display")) {
                    Picker("settings.display.language", selection: $languageManager.currentLanguageCode) {
                        ForEach(languageManager.availableLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .onChange(of: languageManager.currentLanguageCode) { _, newCode in
                        languageManager.changeLanguage(to: newCode)
                        WidgetCenter.shared.reloadTimelines(ofKind: "BeszelWidget")
                    }
                    Picker("settings.display.chartPeriod", selection: $settingsManager.selectedTimeRange) {
                        ForEach(TimeRangeOption.allCases) { option in
                            Text(LocalizedStringKey(option.rawValue)).tag(option)
                        }
                    }
                    .onChange(of: settingsManager.selectedTimeRange) { _, _ in
                        WidgetCenter.shared.reloadTimelines(ofKind: "BeszelWidget")
                    }
                }
                Section(header: Text("settings.dashboard")) {
                    Button("settings.dashboard.clearPins", role: .destructive) {
                        isShowingClearPinsAlert = true
                    }
                    .disabled(dashboardManager.pinnedItems.isEmpty)
                }
                Section(header: Text("settings.account")) {
                    Button("settings.account.disconnect", role: .destructive) {
                        isShowingLogoutAlert = true
                    }
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {dismiss()}) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .alert("settings.account.disconnect.alert.title", isPresented: $isShowingLogoutAlert) {
                Button("common.cancel", role: .cancel) { }
                Button("common.confirm", role: .destructive) {
                    onLogout()
                }
            } message: {
                Text("settings.account.disconnect.alert.message")
            }
            .alert("settings.dashboard.clearPins.alert.title", isPresented: $isShowingClearPinsAlert) {
                Button("common.cancel", role: .cancel) { }
                Button("common.delete", role: .destructive) {
                    dashboardManager.removeAllPins()
                }
            } message: {
                Text("settings.dashboard.clearPins.alert.message")
            }
        }
    }
}
