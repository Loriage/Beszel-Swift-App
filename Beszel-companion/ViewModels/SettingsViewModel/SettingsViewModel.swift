import Foundation
import SwiftUI
import Combine
import WidgetKit

@MainActor
class SettingsViewModel: ObservableObject {
    private let dashboardManager: DashboardManager
    private let settingsManager: SettingsManager
    let languageManager: LanguageManager
    let instanceManager: InstanceManager

    @Published var isShowingClearPinsAlert = false
    @Published var isAddingInstance = false

    init(dashboardManager: DashboardManager, settingsManager: SettingsManager, languageManager: LanguageManager, instanceManager: InstanceManager) {
        self.dashboardManager = dashboardManager
        self.settingsManager = settingsManager
        self.languageManager = languageManager
        self.instanceManager = instanceManager
    }

    var arePinsEmpty: Bool {
        dashboardManager.allPinsForActiveInstance.isEmpty
    }

    var languageCodeBinding: Binding<String> {
        Binding(
            get: { self.languageManager.currentLanguageCode },
            set: {
                self.languageManager.currentLanguageCode = $0
                WidgetCenter.shared.reloadTimelines(ofKind: "BeszelWidget")
            }
        )
    }

    var timeRangeBinding: Binding<TimeRangeOption> {
        Binding(
            get: { self.settingsManager.selectedTimeRange },
            set: {
                self.settingsManager.selectedTimeRange = $0
                WidgetCenter.shared.reloadTimelines(ofKind: "BeszelWidget")
            }
        )
    }

    func setActiveInstance(_ instance: Instance) {
        instanceManager.setActiveInstance(instance)
        WidgetCenter.shared.reloadTimelines(ofKind: "BeszelWidget")
    }

    func deleteInstance(at offsets: IndexSet) {
        offsets.map { self.instanceManager.instances[$0] }.forEach(self.instanceManager.deleteInstance)
    }

    func addInstance(name: String, url: String, email: String, password: String) {
        instanceManager.addInstance(name: name, url: url, email: email, password: password)
        isAddingInstance = false
    }

    func clearAllPins() {
        dashboardManager.removeAllPinsForActiveSystem()
    }

    func nukeAllPins() {
        dashboardManager.nukeAllPins()
    }
}
