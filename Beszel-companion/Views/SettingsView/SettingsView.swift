import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(DashboardManager.self) var dashboardManager
    @Environment(SettingsManager.self) var settingsManager
    @Environment(LanguageManager.self) var languageManager
    @Environment(InstanceManager.self) var instanceManager
    
    @Environment(\.dismiss) var dismiss
    
    @State private var isShowingClearPinsAlert = false
    @State private var isAddingInstance = false
    
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
                
                Section(header: Text("settings.dashboard")) {
                    Button("settings.dashboard.clearPins", role: .destructive) {
                        isShowingClearPinsAlert = true
                    }
                    .disabled(!dashboardManager.hasPinsForActiveInstance())
                }
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
