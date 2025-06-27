import SwiftUI
import WidgetKit

struct SettingsView: View {
    @EnvironmentObject var dashboardManager: DashboardManager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var languageManager: LanguageManager
    @ObservedObject var instanceManager: InstanceManager
    @Environment(\.dismiss) var dismiss

    @State private var isShowingLogoutAlert = false
    @State private var isShowingClearPinsAlert = false
    @State private var isAddingInstance = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("settings.display")) {
                    Picker("settings.display.language", selection: $languageManager.currentLanguageCode) {
                        ForEach(languageManager.availableLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .onChange(of: languageManager.currentLanguageCode) { _, _ in
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
                    .onDelete(perform: deleteInstance)
                    
                    Button("settings.instances.add") {
                        isAddingInstance = true
                    }
                }
                Section(header: Text("settings.dashboard")) {
                    Button("settings.dashboard.clearPins", role: .destructive) {
                        isShowingClearPinsAlert = true
                    }
                    .disabled(dashboardManager.pinnedItems.isEmpty)
                }
                /*Section(header: Text("settings.account")) {
                    Button("settings.account.disconnect", role: .destructive) {
                        isShowingLogoutAlert = true
                    }
                }*/
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
            .sheet(isPresented: $isAddingInstance) {
                OnboardingView(onComplete: { name, url, email, password in
                    instanceManager.addInstance(name: name, url: url, email: email, password: password)
                    isAddingInstance = false
                })
            }
            .alert("settings.account.disconnect.alert.title", isPresented: $isShowingLogoutAlert) {
                Button("common.cancel", role: .cancel) { }
                Button("common.confirm", role: .destructive) {
                    instanceManager.logoutAll()
                    dismiss()
                }
            } message: {
                Text("settings.account.disconnect.alert.message")
            }
            .alert("settings.dashboard.clearPins.alert.title", isPresented: $isShowingClearPinsAlert) {
                Button("common.cancel", role: .cancel) { }
                Button("common.delete", role: .destructive) {
                    dashboardManager.removeAllPinsForActiveInstance()
                }
            } message: {
                Text("settings.dashboard.clearPins.alert.message")
            }
        }
    }

    private func deleteInstance(at offsets: IndexSet) {
        offsets.map { instanceManager.instances[$0] }.forEach(instanceManager.deleteInstance)
    }
}
