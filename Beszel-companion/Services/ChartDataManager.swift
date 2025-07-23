import Foundation
import SwiftUI
import Combine

class ChartDataManager: ObservableObject {
    @Published var systemDataPoints: [SystemDataPoint] = []
    @Published var containerData: [ProcessedContainerData] = []

    private let dataService: DataService
    private let settingsManager: SettingsManager
    private let dashboardManager: DashboardManager
    private let instanceManager: InstanceManager
    private var cancellables = Set<AnyCancellable>()

    init(dataService: DataService, settingsManager: SettingsManager, dashboardManager: DashboardManager, instanceManager: InstanceManager) {
        self.dataService = dataService
        self.settingsManager = settingsManager
        self.dashboardManager = dashboardManager
        self.instanceManager = instanceManager

        dataService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateData()
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        dashboardManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        updateData()
    }

    private func updateData() {
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

    func fetchData() {
        dataService.fetchData()
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
