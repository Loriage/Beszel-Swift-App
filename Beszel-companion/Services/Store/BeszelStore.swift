import Foundation
import SwiftUI
import Observation
import os

private let logger = Logger(subsystem: "com.nohitdev.Beszel", category: "BeszelStore")

@Observable
@MainActor
final class BeszelStore {
    var stackedCpuData: [StackedCpuData] = []
    var cpuDomain: [String] = []
    
    var stackedMemoryData: [StackedMemoryData] = []
    var memoryDomain: [String] = []

    var stackedNetworkData: [StackedNetworkData] = []
    var networkDomain: [String] = []
    
    var systemDataPoints: [SystemDataPoint] = []
    var containerData: [ProcessedContainerData] = [] {
        didSet {
            self.sortedContainerData = containerData.sorted { $0.name < $1.name }
            self.calculateStackedData()
        }
    }
    var sortedContainerData: [ProcessedContainerData] = []
    
    var containerRecords: [ContainerRecord] = []
    var sortedContainerRecords: [ContainerRecord] {
        containerRecords.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var latestSystemStats: SystemStatsRecord?
    
    var isLoading = true
    var errorMessage: String?
    
    private var systemDataPointsBySystem: [String: [SystemDataPoint]] = [:]
    private var containerDataBySystem: [String: [ProcessedContainerData]] = [:]
    private var containerRecordsBySystem: [String: [ContainerRecord]] = [:]
    private var latestStatsBySystem: [String: SystemStatsRecord] = [:]
    
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
    
    var hasSwapData: Bool {
        systemDataPoints.contains { $0.swap != nil }
    }
    
    var hasGPUData: Bool {
        systemDataPoints.contains { !$0.gpuMetrics.isEmpty }
    }
    
    var hasNetworkInterfacesData: Bool {
        systemDataPoints.contains { !$0.networkInterfaces.isEmpty }
    }
    
    var hasDiskUsageData: Bool {
        systemDataPoints.contains { $0.diskUsage != nil }
    }

    var hasContainerNetworkData: Bool {
        containerData.contains { container in
            container.statPoints.contains { $0.netSent > 0 || $0.netReceived > 0 }
        }
    }

    var hasExtraFilesystemsData: Bool {
        systemDataPoints.contains { !$0.extraFilesystems.isEmpty }
    }
    
    func updateDataForActiveSystem() {
        guard let activeSystemID = instanceManager.activeSystem?.id else {
            self.systemDataPoints = []
            self.containerData = []
            self.containerRecords = []
            self.latestSystemStats = nil
            return
        }
        self.systemDataPoints = systemDataPointsBySystem[activeSystemID] ?? []
        self.containerData = containerDataBySystem[activeSystemID] ?? []
        self.containerRecords = containerRecordsBySystem[activeSystemID] ?? []
        self.latestSystemStats = latestStatsBySystem[activeSystemID]
    }
    
    private func cleanupStaleSystemData() {
        let validSystemIDs = Set(instanceManager.systems.map { $0.id })
        
        for systemID in systemDataPointsBySystem.keys where !validSystemIDs.contains(systemID) {
            systemDataPointsBySystem.removeValue(forKey: systemID)
            logger.debug("Cleaned up stale data for system: \(systemID)")
        }
        for systemID in containerDataBySystem.keys where !validSystemIDs.contains(systemID) {
            containerDataBySystem.removeValue(forKey: systemID)
        }
        for systemID in containerRecordsBySystem.keys where !validSystemIDs.contains(systemID) {
            containerRecordsBySystem.removeValue(forKey: systemID)
        }
        for systemID in latestStatsBySystem.keys where !validSystemIDs.contains(systemID) {
            latestStatsBySystem.removeValue(forKey: systemID)
        }
    }
    
    func clearAllCachedData() {
        systemDataPointsBySystem.removeAll()
        containerDataBySystem.removeAll()
        containerRecordsBySystem.removeAll()
        latestStatsBySystem.removeAll()
        systemDataPoints = []
        containerData = []
        containerRecords = []
        latestSystemStats = nil
        stackedCpuData = []
        stackedMemoryData = []
        stackedNetworkData = []
        cpuDomain = []
        memoryDomain = []
        networkDomain = []
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
                async let systemsTask = apiService.fetchSystems()
                async let detailsTask = apiService.fetchSystemDetails()
                
                let fetchedSystems = try await systemsTask
                let fetchedDetails = try await detailsTask
                
                instanceManager.systems = fetchedSystems.sorted(by: { $0.name < $1.name })
                instanceManager.systemDetails = Dictionary(
                    uniqueKeysWithValues: fetchedDetails.map { ($0.system, $0) }
                )
                instanceManager.refreshActiveSystem()
                cleanupStaleSystemData()
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
        
        let apiService = self.apiService
        
        do {
            let (finalSystemData, finalContainerData, finalLatestStats) = try await withThrowingTaskGroup(
                of: (String, [SystemDataPoint], [ProcessedContainerData], SystemStatsRecord?).self,
                returning: ([String: [SystemDataPoint]], [String: [ProcessedContainerData]], [String: SystemStatsRecord]).self
            ) { group in
                
                for system in systemsToFetch {
                    group.addTask {
                        let systemFilter = "system = '\(system.id)'"
                        let filters: [String] = [systemFilter, timeFilter]
                        let finalFilter = "(\(filters.joined(separator: " && ")))"
                        
                        async let containerRecords = apiService.fetchMonitors(filter: finalFilter)
                        async let systemRecords = apiService.fetchSystemStats(filter: finalFilter)
                        
                        let fetchedContainers = try await containerRecords
                        let fetchedSystem = try await systemRecords
                        
                        let rawSystemData = fetchedSystem.asDataPoints()
                        let transformedSystem = BeszelStore.downsampleSystemDataPoints(rawSystemData, timeRange: currentTimeRange)
                        let rawContainers = fetchedContainers.asProcessedData()
                        
                        let latestRecord = fetchedSystem.max(by: { $0.created < $1.created })
                        
                        var processedContainers: [ProcessedContainerData] = []
                        for container in rawContainers {
                            var c = container
                            c.statPoints = await BeszelStore.downsampleStatPoints(container.statPoints, timeRange: currentTimeRange)
                            processedContainers.append(c)
                        }
                        
                        return (system.id, transformedSystem, processedContainers, latestRecord)
                    }
                }
                
                var systemDataResult: [String: [SystemDataPoint]] = [:]
                var containerDataResult: [String: [ProcessedContainerData]] = [:]
                var latestStatsResult: [String: SystemStatsRecord] = [:]

                for try await (systemId, sysData, processedContainers, latestRec) in group {
                    systemDataResult[systemId] = sysData
                    containerDataResult[systemId] = processedContainers
                    if let latestRec = latestRec {
                        latestStatsResult[systemId] = latestRec
                    }
                }

                return (systemDataResult, containerDataResult, latestStatsResult)
            }
            
            self.systemDataPointsBySystem = finalSystemData
            self.containerDataBySystem = finalContainerData
            
            for (id, stat) in finalLatestStats {
                if let existing = self.latestStatsBySystem[id], existing.created > stat.created {
                    continue
                }
                self.latestStatsBySystem[id] = stat
            }
            
            await fetchContainerRecords(for: systemsToFetch)
            
            self.updateDataForActiveSystem()
            
        } catch {
            handleError(error)
        }
    }
    
    private func fetchContainerRecords(for systems: [SystemRecord]) async {
        let apiService = self.apiService
        
        do {
            let allContainers = try await apiService.fetchContainers(filter: nil)
            
            var containersBySystem: [String: [ContainerRecord]] = [:]
            for container in allContainers {
                var systemContainers = containersBySystem[container.system, default: []]
                
                if let existingIndex = systemContainers.firstIndex(where: { $0.name == container.name }) {
                    if container.updated > systemContainers[existingIndex].updated {
                        systemContainers[existingIndex] = container
                    }
                } else {
                    systemContainers.append(container)
                }
                containersBySystem[container.system] = systemContainers
            }
            
            self.containerRecordsBySystem = containersBySystem
        } catch {
            logger.warning("Failed to fetch container records: \(error.localizedDescription)")
        }
    }
    
    func refreshLatestStatsOnly() async {
        let apiService = self.apiService
        
        do {
            async let systemsTask = apiService.fetchSystems()
            async let detailsTask = apiService.fetchSystemDetails()
            
            let fetchedSystems = try await systemsTask
            let fetchedDetails = try await detailsTask
            
            instanceManager.systems = fetchedSystems.sorted(by: { $0.name < $1.name })
            instanceManager.systemDetails = Dictionary(
                uniqueKeysWithValues: fetchedDetails.map { ($0.system, $0) }
            )
            instanceManager.refreshActiveSystem()
            
            if let activeSystemID = instanceManager.activeSystem?.id {
                if let latest = try await apiService.fetchLatestSystemStats(systemID: activeSystemID) {
                    self.latestStatsBySystem[activeSystemID] = latest
                    self.latestSystemStats = latest
                }
            }
            
            self.authenticationFailed = false
        } catch {
            if let urlError = error as? URLError, urlError.code == .userAuthenticationRequired {
                logger.warning("Authentication failed during refresh")
                self.authenticationFailed = true
            } else {
                logger.error("Error during quick refresh: \(error.localizedDescription)")
            }
        }
    }
    
    var authenticationFailed = false
    
    private func handleError(_ error: Error) {
        if let urlError = error as? URLError, urlError.code == .userAuthenticationRequired {
            logger.warning("Authentication failed")
            self.authenticationFailed = true
            self.errorMessage = String(localized: "common.error.authFailed")
        } else if let decodingError = error as? DecodingError {
            let details: String
            switch decodingError {
            case .keyNotFound(let key, let context):
                details = "Missing key '\(key.stringValue)' at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            case .typeMismatch(let type, let context):
                details = "Type mismatch for \(type) at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            case .valueNotFound(let type, let context):
                details = "Value not found for \(type) at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            case .dataCorrupted(let context):
                details = "Data corrupted at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            @unknown default:
                details = "Unknown decoding error"
            }
            logger.error("Decoding error: \(details)")
            self.errorMessage = String(localized: "common.error.fetchFailed") + ": \(details)"
        } else {
            logger.error("Failed to fetch data: \(error.localizedDescription)")
            self.errorMessage = String(localized: "common.error.fetchFailed") + ": \(error.localizedDescription)"
        }
    }
    
    func clearAuthenticationError() {
        authenticationFailed = false
        errorMessage = nil
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
    
    func latestStats(for systemID: String) -> SystemStatsRecord? {
        latestStatsBySystem[systemID]
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
    
    nonisolated private static func downsampleSystemDataPoints(_ dataPoints: [SystemDataPoint], timeRange: TimeRangeOption) -> [SystemDataPoint] {
        guard !dataPoints.isEmpty else { return [] }
        if dataPoints.count < 150 { return dataPoints }
        
        let sortedPoints = dataPoints.sorted { $0.date < $1.date }
        let minDate = sortedPoints.first?.date ?? Date()
        let maxDate = sortedPoints.last?.date ?? Date()
        let totalDuration = maxDate.timeIntervalSince(minDate)
        
        let targetCount: Int
        switch timeRange {
        case .lastHour: targetCount = 120
        default: targetCount = 100
        }
        
        let minInterval: TimeInterval
        switch timeRange {
        case .lastHour, .last12Hours: minInterval = 30
        case .last24Hours: minInterval = 60
        case .last7Days: minInterval = 300
        case .last30Days: minInterval = 900
        }
        
        let calculatedInterval = max(minInterval, totalDuration / Double(max(1, targetCount)))
        
        return sortedPoints.downsampled(bucketInterval: calculatedInterval)
    }
    
    private func calculateStackedData() {
        let timeRange = settingsManager.selectedTimeRange

        let avgCpu = containerData.map { container -> (name: String, avg: Double) in
            let total = container.statPoints.reduce(0) { $0 + $1.cpu }
            let average = container.statPoints.isEmpty ? 0 : total / Double(container.statPoints.count)
            return (name: container.name, avg: average)
        }
        self.cpuDomain = avgCpu.sorted { $0.avg < $1.avg }.map { $0.name }

        self.stackedCpuData = buildStackedCpuData(from: containerData, domain: cpuDomain, timeRange: timeRange)

        let avgMem = containerData.map { container -> (name: String, avg: Double) in
            let total = container.statPoints.reduce(0) { $0 + $1.memory }
            let average = container.statPoints.isEmpty ? 0 : total / Double(container.statPoints.count)
            return (name: container.name, avg: average)
        }
        self.memoryDomain = avgMem.sorted { $0.avg < $1.avg }.map { $0.name }

        self.stackedMemoryData = buildStackedMemoryData(from: containerData, domain: memoryDomain, timeRange: timeRange)

        let avgNet = containerData.map { container -> (name: String, avg: Double) in
            let total = container.statPoints.reduce(0) { $0 + $1.netSent + $1.netReceived }
            let average = container.statPoints.isEmpty ? 0 : total / Double(container.statPoints.count)
            return (name: container.name, avg: average)
        }
        self.networkDomain = avgNet.sorted { $0.avg < $1.avg }.map { $0.name }

        self.stackedNetworkData = buildStackedNetworkData(from: containerData, domain: networkDomain, timeRange: timeRange)
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

        return (buildStackedCpuData(from: data, domain: domain, timeRange: settingsManager.selectedTimeRange), domain)
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

        return (buildStackedMemoryData(from: data, domain: domain, timeRange: settingsManager.selectedTimeRange), domain)
    }

    func getStackedNetworkData(for systemID: String) -> (data: [StackedNetworkData], domain: [String]) {
        if systemID == instanceManager.activeSystem?.id {
            return (stackedNetworkData, networkDomain)
        }

        let data = containerDataBySystem[systemID] ?? []

        let avg = data.map { c -> (String, Double) in
            let total = c.statPoints.reduce(0) { $0 + $1.netSent + $1.netReceived }
            let mean = c.statPoints.isEmpty ? 0 : total / Double(c.statPoints.count)
            return (c.name, mean)
        }
        let domain = avg.sorted { $0.1 < $1.1 }.map { $0.0 }

        return (buildStackedNetworkData(from: data, domain: domain, timeRange: settingsManager.selectedTimeRange), domain)
    }

    /// Returns bucket interval in seconds based on time range
    private func bucketInterval(for timeRange: TimeRangeOption) -> TimeInterval {
        switch timeRange {
        case .lastHour: return 60          // 1 minute
        case .last12Hours: return 300      // 5 minutes
        case .last24Hours: return 600      // 10 minutes
        case .last7Days: return 3600       // 1 hour
        case .last30Days: return 14400     // 4 hours
        }
    }

    /// Rounds a date to the nearest bucket based on time range
    private func bucketDate(_ date: Date, interval: TimeInterval) -> Date {
        let ts = date.timeIntervalSince1970
        let bucketedTs = (ts / interval).rounded() * interval
        return Date(timeIntervalSince1970: bucketedTs)
    }

    func buildStackedCpuData(from data: [ProcessedContainerData], domain: [String], timeRange: TimeRangeOption? = nil) -> [StackedCpuData] {
        let interval = bucketInterval(for: timeRange ?? settingsManager.selectedTimeRange)
        let allPoints = data.flatMap { container in
            container.statPoints.map { AggregatedCpuData(date: $0.date, name: container.name, cpu: $0.cpu) }
        }
        guard !allPoints.isEmpty else { return [] }

        // Bucket dates based on time range to reduce noise
        let pointDict = Dictionary(grouping: allPoints, by: { bucketDate($0.date, interval: interval) })
        let uniqueDates = pointDict.keys.sorted()
        let uniqueNames = Set(allPoints.map { $0.name })

        let domainIndexMap = Dictionary(uniqueKeysWithValues: domain.enumerated().map { ($1, $0) })

        var stacked: [StackedCpuData] = []

        // Track last known value for each container to interpolate missing data
        var lastKnownValue: [String: Double] = [:]
        for name in uniqueNames {
            lastKnownValue[name] = 0
        }

        for date in uniqueDates {
            let pointsInBucket = pointDict[date] ?? []

            // Average values per container within each bucket
            var avgByName: [String: Double] = [:]
            var countByName: [String: Int] = [:]
            for point in pointsInBucket {
                avgByName[point.name, default: 0] += point.cpu
                countByName[point.name, default: 0] += 1
            }
            for (name, total) in avgByName {
                avgByName[name] = total / Double(countByName[name] ?? 1)
            }

            // Fill missing containers with last known value (interpolation)
            for name in uniqueNames {
                if let value = avgByName[name] {
                    lastKnownValue[name] = value
                } else {
                    avgByName[name] = lastKnownValue[name] ?? 0
                }
            }

            // Sort by domain order and build stacked data
            let sortedNames = avgByName.keys.sorted {
                (domainIndexMap[$0] ?? 0) < (domainIndexMap[$1] ?? 0)
            }

            var cumulative = 0.0
            for name in sortedNames {
                let val = avgByName[name] ?? 0
                stacked.append(StackedCpuData(date: date, name: name, yStart: cumulative, yEnd: cumulative + val))
                cumulative += val
            }
        }
        return stacked
    }
    
    func buildStackedMemoryData(from data: [ProcessedContainerData], domain: [String], timeRange: TimeRangeOption? = nil) -> [StackedMemoryData] {
        let interval = bucketInterval(for: timeRange ?? settingsManager.selectedTimeRange)
        let allPoints = data.flatMap { container in
            container.statPoints.map { AggregatedMemoryData(date: $0.date, name: container.name, memory: $0.memory) }
        }
        guard !allPoints.isEmpty else { return [] }

        // Bucket dates based on time range to reduce noise
        let pointDict = Dictionary(grouping: allPoints, by: { bucketDate($0.date, interval: interval) })
        let uniqueDates = pointDict.keys.sorted()
        let uniqueNames = Set(allPoints.map { $0.name })

        let domainIndexMap = Dictionary(uniqueKeysWithValues: domain.enumerated().map { ($1, $0) })

        var stacked: [StackedMemoryData] = []

        // Track last known value for each container to interpolate missing data
        var lastKnownValue: [String: Double] = [:]
        for name in uniqueNames {
            lastKnownValue[name] = 0
        }

        for date in uniqueDates {
            let pointsInBucket = pointDict[date] ?? []

            // Average values per container within each bucket
            var avgByName: [String: Double] = [:]
            var countByName: [String: Int] = [:]
            for point in pointsInBucket {
                avgByName[point.name, default: 0] += point.memory
                countByName[point.name, default: 0] += 1
            }
            for (name, total) in avgByName {
                avgByName[name] = total / Double(countByName[name] ?? 1)
            }

            // Fill missing containers with last known value (interpolation)
            for name in uniqueNames {
                if let value = avgByName[name] {
                    lastKnownValue[name] = value
                } else {
                    avgByName[name] = lastKnownValue[name] ?? 0
                }
            }

            // Sort by domain order and build stacked data
            let sortedNames = avgByName.keys.sorted {
                (domainIndexMap[$0] ?? 0) < (domainIndexMap[$1] ?? 0)
            }

            var cumulative = 0.0
            for name in sortedNames {
                let val = avgByName[name] ?? 0
                stacked.append(StackedMemoryData(date: date, name: name, yStart: cumulative, yEnd: cumulative + val))
                cumulative += val
            }
        }
        return stacked
    }

    func buildStackedNetworkData(from data: [ProcessedContainerData], domain: [String], timeRange: TimeRangeOption? = nil) -> [StackedNetworkData] {
        let interval = bucketInterval(for: timeRange ?? settingsManager.selectedTimeRange)
        let allPoints = data.flatMap { container in
            container.statPoints.map { AggregatedNetworkData(date: $0.date, name: container.name, netSent: $0.netSent, netReceived: $0.netReceived) }
        }
        guard !allPoints.isEmpty else { return [] }

        let pointDict = Dictionary(grouping: allPoints, by: { bucketDate($0.date, interval: interval) })
        let uniqueDates = pointDict.keys.sorted()
        let uniqueNames = Set(allPoints.map { $0.name })

        let domainIndexMap = Dictionary(uniqueKeysWithValues: domain.enumerated().map { ($1, $0) })

        var stacked: [StackedNetworkData] = []

        var lastKnownSent: [String: Double] = [:]
        var lastKnownReceived: [String: Double] = [:]
        for name in uniqueNames {
            lastKnownSent[name] = 0
            lastKnownReceived[name] = 0
        }

        for date in uniqueDates {
            let pointsInBucket = pointDict[date] ?? []

            var avgSentByName: [String: Double] = [:]
            var avgReceivedByName: [String: Double] = [:]
            var countByName: [String: Int] = [:]
            for point in pointsInBucket {
                avgSentByName[point.name, default: 0] += point.netSent
                avgReceivedByName[point.name, default: 0] += point.netReceived
                countByName[point.name, default: 0] += 1
            }
            for (name, total) in avgSentByName {
                let count = Double(countByName[name] ?? 1)
                avgSentByName[name] = total / count
                avgReceivedByName[name] = (avgReceivedByName[name] ?? 0) / count
            }

            for name in uniqueNames {
                if let sent = avgSentByName[name] {
                    lastKnownSent[name] = sent
                    lastKnownReceived[name] = avgReceivedByName[name] ?? 0
                } else {
                    avgSentByName[name] = lastKnownSent[name] ?? 0
                    avgReceivedByName[name] = lastKnownReceived[name] ?? 0
                }
            }

            let sortedNames = avgSentByName.keys.sorted {
                (domainIndexMap[$0] ?? 0) < (domainIndexMap[$1] ?? 0)
            }

            var cumulative = 0.0
            for name in sortedNames {
                let sent = avgSentByName[name] ?? 0
                let received = avgReceivedByName[name] ?? 0
                let total = sent + received
                stacked.append(StackedNetworkData(date: date, name: name, yStart: cumulative, yEnd: cumulative + total, netSent: sent, netReceived: received))
                cumulative += total
            }
        }
        return stacked
    }
}
