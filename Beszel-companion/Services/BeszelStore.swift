import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class BeszelStore {
    var systemDataPoints: [SystemDataPoint] = []
    var containerData: [ProcessedContainerData] = [] {
        didSet {
            self.sortedContainerData = containerData.sorted { $0.name < $1.name }
        }
    }
    var sortedContainerData: [ProcessedContainerData] = []
    
    var isLoading = true
    var errorMessage: String?
    
    private var systemDataPointsBySystem: [String: [SystemDataPoint]] = [:]
    private var containerDataBySystem: [String: [ProcessedContainerData]] = [:]
    
    private let apiService: BeszelAPIService
    private let settingsManager: SettingsManager
    private let dashboardManager: DashboardManager
    private let instanceManager: InstanceManager
    
    init(instance: Instance, settingsManager: SettingsManager, dashboardManager: DashboardManager, instanceManager: InstanceManager) {
        self.apiService = BeszelAPIService(instance: instance, instanceManager: instanceManager)
        self.settingsManager = settingsManager
        self.dashboardManager = dashboardManager
        self.instanceManager = instanceManager
        
        updateDataForActiveSystem()
    }
    
    var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }
    
    var hasTemperatureData: Bool {
        systemDataPoints.contains { !$0.temperatures.isEmpty }
    }
    
    func updateDataForActiveSystem() {
        guard let activeSystemID = instanceManager.activeSystem?.id else {
            self.systemDataPoints = []
            self.containerData = []
            return
        }
        self.systemDataPoints = systemDataPointsBySystem[activeSystemID] ?? []
        self.containerData = containerDataBySystem[activeSystemID] ?? []
    }
    
    func fetchData() async {
        self.isLoading = true
        self.errorMessage = nil
        
        let systemsToFetch = instanceManager.systems
        let timeFilter = settingsManager.selectedTimeRange.apiFilterString
        let currentTimeRange = settingsManager.selectedTimeRange
        
        defer { self.isLoading = false }
        
        guard !systemsToFetch.isEmpty else {
            self.systemDataPointsBySystem = [:]
            self.containerDataBySystem = [:]
            updateDataForActiveSystem()
            return
        }
        
        do {
            let (finalSystemData, finalContainerData) = try await withThrowingTaskGroup(
                of: (String, [SystemDataPoint], [ProcessedContainerData]).self,
                returning: ([String: [SystemDataPoint]], [String: [ProcessedContainerData]]).self
            ) { group in
                
                for system in systemsToFetch {
                    group.addTask {
                        let systemFilter = "system = '\(system.id)'"
                        let filters: [String] = [systemFilter, timeFilter]
                        let finalFilter = "(\(filters.joined(separator: " && ")))"
                        
                        async let containerRecords = self.apiService.fetchMonitors(filter: finalFilter)
                        async let systemRecords = self.apiService.fetchSystemStats(filter: finalFilter)
                        
                        let fetchedContainers = try await containerRecords
                        let fetchedSystem = try await systemRecords
                        
                        let transformedSystem = DataProcessor.transformSystem(records: fetchedSystem)
                        let rawContainers = DataProcessor.transform(records: fetchedContainers)
                        
                        var processedContainers: [ProcessedContainerData] = []
                        for container in rawContainers {
                            var c = container
                            c.statPoints = await BeszelStore.downsampleStatPoints(container.statPoints, timeRange: currentTimeRange)
                            processedContainers.append(c)
                        }
                        
                        return (system.id, transformedSystem, processedContainers)
                    }
                }
                
                return try await group.reduce(into: ([:], [:])) { (partialResult, taskResult) in
                    let (systemId, sysData, processedContainers) = taskResult
                    partialResult.0[systemId] = sysData
                    partialResult.1[systemId] = processedContainers
                }
            }
            
            self.systemDataPointsBySystem = finalSystemData
            self.containerDataBySystem = finalContainerData
            self.updateDataForActiveSystem()
            
        } catch {
            print("Error fetching data: \(error)")
            self.errorMessage = "Failed to fetch data: \(error.localizedDescription)"
        }
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
        systemDataPointsBySystem[systemID] ?? []
    }
    
    func containerData(forSystemID systemID: String) -> [ProcessedContainerData] {
        containerDataBySystem[systemID] ?? []
    }
    
    func systemName(forSystemID systemID: String) -> String? {
        instanceManager.systems.first { $0.id == systemID }?.name
    }
    
    nonisolated private static func downsampleStatPoints(_ statPoints: [StatPoint], timeRange: TimeRangeOption) async -> [StatPoint] {
        guard !statPoints.isEmpty else { return [] }
        if statPoints.count < 150 { return statPoints }
        
        let targetCount: Int
        switch timeRange {
        case .lastHour: targetCount = 120
        default: targetCount = 100
        }
        
        let minDate = statPoints.first?.date ?? Date()
        let maxDate = statPoints.last?.date ?? Date()
        let totalDuration = maxDate.timeIntervalSince(minDate)
        
        let minInterval: TimeInterval
        switch timeRange {
        case .lastHour, .last12Hours: minInterval = 30
        case .last24Hours: minInterval = 60
        case .last7Days: minInterval = 300
        case .last30Days: minInterval = 900
        }
        
        let calculatedInterval = max(minInterval, totalDuration / Double(max(1, targetCount)))
        
        return statPoints.downsampled(bucketInterval: calculatedInterval, method: .average)
    }
}
