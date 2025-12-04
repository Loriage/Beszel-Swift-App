import Foundation
import SwiftUI
import Observation
import WidgetKit

@Observable
@MainActor
final class SettingsViewModel {
    private let dashboardManager: DashboardManager
    let settingsManager: SettingsManager
    let languageManager: LanguageManager
    let instanceManager: InstanceManager
    
    var isShowingClearPinsAlert = false
    var isAddingInstance = false
    
    init(dashboardManager: DashboardManager, settingsManager: SettingsManager, languageManager: LanguageManager, instanceManager: InstanceManager) {
        self.dashboardManager = dashboardManager
        self.settingsManager = settingsManager
        self.languageManager = languageManager
        self.instanceManager = instanceManager
    }
    
    var arePinsEmpty: Bool {
        !dashboardManager.hasPinsForActiveInstance()
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
