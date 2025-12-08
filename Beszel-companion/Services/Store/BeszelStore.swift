import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class BeszelStore {
    var stackedCpuData: [StackedCpuData] = []
    var cpuDomain: [String] = []
    
    var stackedMemoryData: [StackedMemoryData] = []
    var memoryDomain: [String] = []
    
    var systemDataPoints: [SystemDataPoint] = []
    var containerData: [ProcessedContainerData] = [] {
        didSet {
            self.sortedContainerData = containerData.sorted { $0.name < $1.name }
            
            Task { @MainActor in
                self.calculateStackedData()
            }
        }
    }
    var sortedContainerData: [ProcessedContainerData] = []
    
    var isLoading = true
    var errorMessage: String?
    
    private var systemDataPointsBySystem: [String: [SystemDataPoint]] = [:]
    private var containerDataBySystem: [String: [ProcessedContainerData]] = [:]
    
    private let instance: Instance
    private let apiService: BeszelAPIService
    private let settingsManager: SettingsManager
    private let dashboardManager: DashboardManager
    private let instanceManager: InstanceManager
    
    init(instance: Instance, settingsManager: SettingsManager, dashboardManager: DashboardManager, instanceManager: InstanceManager) {
        self.instance = instance
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
        
        var systemsToFetch = instanceManager.systems
        let timeFilter = settingsManager.selectedTimeRange.apiFilterString
        let currentTimeRange = settingsManager.selectedTimeRange
        
        defer { self.isLoading = false }
        
        if systemsToFetch.isEmpty {
            do {
                let fetchedSystems = try await apiService.fetchSystems()
                instanceManager.systems = fetchedSystems.sorted(by: { $0.name < $1.name })
                systemsToFetch = instanceManager.systems

                if systemsToFetch.isEmpty {
                    updateDataForActiveSystem()
                    return
                }
            } catch {
                handleError(error)
                return
            }
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
                        
                        let transformedSystem = fetchedSystem.asDataPoints()
                        let rawContainers = fetchedContainers.asProcessedData()
                        
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
            handleError(error)
        }
    }
    
    private func handleError(_ error: Error) {
        if let urlError = error as? URLError, urlError.code == .userAuthenticationRequired {
            instanceManager.deleteInstance(self.instance)
        } else {
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
    
    private func calculateStackedData() {
        let avgCpu = containerData.map { container -> (name: String, avg: Double) in
            let total = container.statPoints.reduce(0) { $0 + $1.cpu }
            let average = container.statPoints.isEmpty ? 0 : total / Double(container.statPoints.count)
            return (name: container.name, avg: average)
        }
        self.cpuDomain = avgCpu.sorted { $0.avg < $1.avg }.map { $0.name }
        
        self.stackedCpuData = buildStackedCpuData(from: containerData, domain: cpuDomain)
        
        let avgMem = containerData.map { container -> (name: String, avg: Double) in
            let total = container.statPoints.reduce(0) { $0 + $1.memory }
            let average = container.statPoints.isEmpty ? 0 : total / Double(container.statPoints.count)
            return (name: container.name, avg: average)
        }
        self.memoryDomain = avgMem.sorted { $0.avg < $1.avg }.map { $0.name }
        
        self.stackedMemoryData = buildStackedMemoryData(from: containerData, domain: memoryDomain)
    }
    
    func getStackedCpuData(for systemID: String) -> (data: [StackedCpuData], domain: [String]) {
        if systemID == instanceManager.activeSystem?.id {
            return (stackedCpuData, cpuDomain)
        }
        
        let data = containerDataBySystem[systemID] ?? []
        
        let avg = data.map { c -> (String, Double) in
            let total = c.statPoints.reduce(0) { $0 + $1.cpu }
            let mean = c.statPoints.isEmpty ? 0 : total / Double(c.statPoints.count)
            return (c.name, mean)
        }
        let domain = avg.sorted { $0.1 < $1.1 }.map { $0.0 }
        
        return (buildStackedCpuData(from: data, domain: domain), domain)
    }
    
    func getStackedMemoryData(for systemID: String) -> (data: [StackedMemoryData], domain: [String]) {
        if systemID == instanceManager.activeSystem?.id {
            return (stackedMemoryData, memoryDomain)
        }
        
        let data = containerDataBySystem[systemID] ?? []
        
        let avg = data.map { c -> (String, Double) in
            let total = c.statPoints.reduce(0) { $0 + $1.memory }
            let mean = c.statPoints.isEmpty ? 0 : total / Double(c.statPoints.count)
            return (c.name, mean)
        }
        let domain = avg.sorted { $0.1 < $1.1 }.map { $0.0 }
        
        return (buildStackedMemoryData(from: data, domain: domain), domain)
    }
    
    func buildStackedCpuData(from data: [ProcessedContainerData], domain: [String]) -> [StackedCpuData] {
        let allPoints = data.flatMap { container in
            container.statPoints.map { AggregatedCpuData(date: $0.date, name: container.name, cpu: $0.cpu) }
        }
        guard !allPoints.isEmpty else { return [] }
        
        let uniqueDates = Set(allPoints.map { $0.date }).sorted()
        let uniqueNames = Set(allPoints.map { $0.name })
        let pointDict = Dictionary(grouping: allPoints, by: { $0.date })
        
        var stacked: [StackedCpuData] = []
        
        for date in uniqueDates {
            var pointsForDate = pointDict[date] ?? []
            
            let namesWithData = Set(pointsForDate.map { $0.name })
            let missingNames = uniqueNames.subtracting(namesWithData)
            for name in missingNames {
                pointsForDate.append(AggregatedCpuData(date: date, name: name, cpu: 0))
            }
            
            pointsForDate.sort {
                (domain.firstIndex(of: $0.name) ?? 0) < (domain.firstIndex(of: $1.name) ?? 0)
            }
            
            var cumulative = 0.0
            for point in pointsForDate {
                let val = point.cpu
                stacked.append(StackedCpuData(date: date, name: point.name, yStart: cumulative, yEnd: cumulative + val))
                cumulative += val
            }
        }
        return stacked
    }
    
    func buildStackedMemoryData(from data: [ProcessedContainerData], domain: [String]) -> [StackedMemoryData] {
        let allPoints = data.flatMap { container in
            container.statPoints.map { AggregatedMemoryData(date: $0.date, name: container.name, memory: $0.memory) }
        }
        guard !allPoints.isEmpty else { return [] }
        
        let uniqueDates = Set(allPoints.map { $0.date }).sorted()
        let uniqueNames = Set(allPoints.map { $0.name })
        let pointDict = Dictionary(grouping: allPoints, by: { $0.date })
        
        var stacked: [StackedMemoryData] = []
        
        for date in uniqueDates {
            var pointsForDate = pointDict[date] ?? []
            let namesWithData = Set(pointsForDate.map { $0.name })
            let missingNames = uniqueNames.subtracting(namesWithData)
            for name in missingNames {
                pointsForDate.append(AggregatedMemoryData(date: date, name: name, memory: 0))
            }
            
            pointsForDate.sort {
                (domain.firstIndex(of: $0.name) ?? 0) < (domain.firstIndex(of: $1.name) ?? 0)
            }
            
            var cumulative = 0.0
            for point in pointsForDate {
                let val = point.memory
                stacked.append(StackedMemoryData(date: date, name: point.name, yStart: cumulative, yEnd: cumulative + val))
                cumulative += val
            }
        }
        return stacked
    }
}
