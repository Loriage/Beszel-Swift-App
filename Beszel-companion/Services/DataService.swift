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
    
    nonisolated private func downsampleStatPoints(_ statPoints: [StatPoint], timeRange: TimeRangeOption) -> [StatPoint] {
        guard !statPoints.isEmpty else { return [] }
        
        let targetCount: Int
        switch timeRange {
        case .lastHour: targetCount = 600
        default: targetCount = 300
        }
        
        let minDate = statPoints.min(by: { $0.date < $1.date })?.date ?? Date()
        let maxDate = statPoints.max(by: { $0.date < $1.date })?.date ?? Date()
        let totalDuration = maxDate.timeIntervalSince(minDate)
        
        let minInterval: TimeInterval
        switch timeRange {
        case .lastHour, .last12Hours: minInterval = 30
        case .last24Hours: minInterval = 60
        case .last7Days: minInterval = 300
        case .last30Days: minInterval = 900
        }
        
        let calculatedInterval = max(minInterval, totalDuration / Double(targetCount))
        
        return statPoints.downsampled(bucketInterval: calculatedInterval, method: .average)
    }
    
    func fetchData() async {
        self.isLoading = true
        self.errorMessage = nil
        
        defer { self.isLoading = false }
        
        let systemsToFetch = InstanceManager.shared.systems
        
        let timeFilter = self.settingsManager.apiFilterString
        let currentTimeRange = self.settingsManager.selectedTimeRange
        
        guard !systemsToFetch.isEmpty else {
            self.systemDataPointsBySystem = [:]
            self.containerDataBySystem = [:]
            return
        }
        
        do {
            let (finalSystemData, finalContainerData) = try await withThrowingTaskGroup(of: (systemId: String, systemData: [SystemDataPoint], containerData: [ProcessedContainerData]).self, returning: ([String: [SystemDataPoint]], [String: [ProcessedContainerData]]).self) { group in
                
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

                        return await Task.detached(priority: .userInitiated) {
                            let transformedSystem = DataProcessor.transformSystem(records: fetchedSystem)
                            let transformedContainers = DataProcessor.transform(records: fetchedContainers)

                            return (system.id, transformedSystem, transformedContainers)
                        }.value
                    }
                }
                
                return try await group.reduce(into: ([:], [:])) { (partialResult, taskResult) in
                    let (systemId, sysData, rawContainers) = taskResult

                    let processedContainers = rawContainers.map { container in
                        var c = container
                        c.statPoints = self.downsampleStatPoints(container.statPoints, timeRange: currentTimeRange)
                        return c
                    }
                    
                    partialResult.0[systemId] = sysData
                    partialResult.1[systemId] = processedContainers
                }
            }
            
            self.systemDataPointsBySystem = finalSystemData
            self.containerDataBySystem = finalContainerData
            
        } catch {
            self.errorMessage = "Failed to fetch data: \(error.localizedDescription)"
            self.systemDataPointsBySystem = [:]
            self.containerDataBySystem = [:]
        }
    }
}
