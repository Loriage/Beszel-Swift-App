import SwiftUI
import WidgetKit

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss

    init(dashboardManager: DashboardManager, settingsManager: SettingsManager, languageManager: LanguageManager, instanceManager: InstanceManager) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            dashboardManager: dashboardManager,
            settingsManager: settingsManager,
            languageManager: languageManager,
            instanceManager: instanceManager
        ))
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("settings.display")) {
                    Picker("settings.display.language", selection: viewModel.languageCodeBinding) {
                        ForEach(viewModel.languageManager.availableLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    
                    Picker("settings.display.chartPeriod", selection: viewModel.timeRangeBinding) {
                        ForEach(TimeRangeOption.allCases) { option in
                            Text(LocalizedStringKey(option.rawValue)).tag(option)
                        }
                    }
                }
                
                Section(header: Text("settings.instances.title")) {
                    ForEach(viewModel.instanceManager.instances) { instance in
                        HStack {
                            Image(systemName: "server.rack")
                            Text(instance.name)
                            Spacer()
                            if instance.id == viewModel.instanceManager.activeInstance?.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.setActiveInstance(instance)
                        }
                    }
                    .onDelete(perform: viewModel.deleteInstance)
                    
                    Button("settings.instances.add") {
                        viewModel.isAddingInstance = true
                    }
                }
                
                Section(header: Text("settings.dashboard")) {
                    Button("settings.dashboard.clearPins", role: .destructive) {
                        viewModel.isShowingClearPinsAlert = true
                    }
                    .disabled(viewModel.arePinsEmpty)
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .sheet(isPresented: $viewModel.isAddingInstance) {
                OnboardingView(viewModel: OnboardingViewModel(onComplete: viewModel.addInstance))
            }
            .alert("settings.dashboard.clearPins.alert.title", isPresented: $viewModel.isShowingClearPinsAlert) {
                Button("common.cancel", role: .cancel) { }
                Button("common.delete", role: .destructive) {
                    viewModel.clearAllPins()
                }
            } message: {
                Text("settings.dashboard.clearPins.alert.message")
            }
        }
    }
}
