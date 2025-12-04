import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class DataService {
    var containerDataBySystem: [String: [ProcessedContainerData]] = [:]
    var systemDataPointsBySystem: [String: [SystemDataPoint]] = [:]
    var isLoading = true
    var errorMessage: String?
    
    private let apiService: BeszelAPIService
    private let settingsManager: SettingsManager
    
    init(instance: Instance, settingsManager: SettingsManager, instanceManager: InstanceManager) {
        self.settingsManager = settingsManager
        self.apiService = BeszelAPIService(instance: instance, instanceManager: instanceManager)
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
    
    func fetchData() async {
        self.isLoading = true
        self.errorMessage = nil
        
        let systemsToFetch = InstanceManager.shared.systems
        let timeFilter = self.settingsManager.apiFilterString
        let currentTimeRange = self.settingsManager.selectedTimeRange
        
        defer { self.isLoading = false }
        
        guard !systemsToFetch.isEmpty else {
            self.systemDataPointsBySystem = [:]
            self.containerDataBySystem = [:]
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
                        var filters: [String] = [systemFilter]
                        
                        if let capturedTimeFilter = timeFilter {
                            filters.append(capturedTimeFilter)
                        }
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
                            c.statPoints = await DataService.downsampleStatPoints(container.statPoints, timeRange: currentTimeRange)
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
            
        } catch {
            print("Error fetching data: \(error)")
            self.errorMessage = "Failed to fetch data: \(error.localizedDescription)"
        }
    }
}
