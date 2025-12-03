import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class ChartDataManager {
    var systemDataPoints: [SystemDataPoint] = []
    var containerData: [ProcessedContainerData] = []
    
    private let dataService: DataService
    private let settingsManager: SettingsManager
    private let dashboardManager: DashboardManager
    private let instanceManager: InstanceManager
    
    init(dataService: DataService, settingsManager: SettingsManager, dashboardManager: DashboardManager, instanceManager: InstanceManager) {
        self.dataService = dataService
        self.settingsManager = settingsManager
        self.dashboardManager = dashboardManager
        self.instanceManager = instanceManager
        
        updateData()
    }
    
    var isLoading: Bool {
        dataService.isLoading
    }
    
    var errorMessage: String? {
        dataService.errorMessage
    }
    
    func updateData() {
        guard let activeSystemID = instanceManager.activeSystem?.id else {
            self.systemDataPoints = []
            self.containerData = []
            return
        }
        self.systemDataPoints = dataService.systemDataPointsBySystem[activeSystemID] ?? []
        self.containerData = dataService.containerDataBySystem[activeSystemID] ?? []
    }
    
    var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }
    
    var hasTemperatureData: Bool {
        systemDataPoints.contains { !$0.temperatures.isEmpty }
    }

    func fetchData() async {
        await dataService.fetchData()
        self.updateData()
    }

    func isPinned(_ item: PinnedItem, onSystem systemID: String) -> Bool {
        dashboardManager.isPinned(item, onSystem: systemID)
    }
    
    func isPinned(_ item: PinnedItem) -> Bool {
        dashboardManager.isPinned(item)
    }
    
    func togglePin(for item: PinnedItem, onSystem systemID: String) {
        dashboardManager.togglePin(for: item, onSystem: systemID)
    }
    
    func togglePin(for item: PinnedItem) {
        dashboardManager.togglePin(for: item)
    }
    
    func systemData(forSystemID systemID: String) -> [SystemDataPoint] {
        dataService.systemDataPointsBySystem[systemID] ?? []
    }
    
    func containerData(forSystemID systemID: String) -> [ProcessedContainerData] {
        dataService.containerDataBySystem[systemID] ?? []
    }
    
    func systemName(forSystemID systemID: String) -> String? {
        instanceManager.systems.first { $0.id == systemID }?.name
    }
}
