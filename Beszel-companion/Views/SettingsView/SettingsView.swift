import SwiftUI
import WidgetKit

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss

    init(dashboardManager: DashboardManager, settingsManager: SettingsManager, languageManager: LanguageManager, instanceManager: InstanceManager) {
        _viewModel = State(wrappedValue: SettingsViewModel(
            dashboardManager: dashboardManager,
            settingsManager: settingsManager,
            languageManager: languageManager,
            instanceManager: instanceManager
        ))
    }

    var body: some View {
        // Pour créer des bindings ($viewModel.property), on utilise @Bindable
        @Bindable var bindableViewModel = viewModel
        @Bindable var bindableLanguageManager = viewModel.languageManager
        @Bindable var bindableSettingsManager = viewModel.settingsManager // Nécessite d'exposer SettingsManager via ViewModel ou Environment

        NavigationView {
            Form {
                Section(header: Text("settings.display")) {
                    Picker("settings.display.language", selection: $bindableLanguageManager.currentLanguageCode) {
                        ForEach(viewModel.languageManager.availableLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .onChange(of: viewModel.languageManager.currentLanguageCode) {
                        WidgetCenter.shared.reloadTimelines(ofKind: "BeszelWidget")
                    }
                    
                    Picker("settings.display.chartPeriod", selection: $bindableSettingsManager.selectedTimeRange) {
                        ForEach(TimeRangeOption.allCases) { option in
                            Text(LocalizedStringKey(option.rawValue)).tag(option)
                        }
                    }
                    .onChange(of: viewModel.settingsManager.selectedTimeRange) { // Utilisation correcte du SettingsManager exposé
                         WidgetCenter.shared.reloadTimelines(ofKind: "BeszelWidget")
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
            .sheet(isPresented: $bindableViewModel.isAddingInstance) {
                OnboardingView(viewModel: OnboardingViewModel(onComplete: viewModel.addInstance))
            }
            .alert("settings.dashboard.clearPins.alert.title", isPresented: $bindableViewModel.isShowingClearPinsAlert) {
                Button("common.cancel", role: .cancel) { }
                Button("common.delete", role: .destructive) {
                    viewModel.nukeAllPins()
                }
            } message: {
                Text("settings.dashboard.clearPins.alert.message")
            }
        }
    }
}
