import Foundation
import Combine
import SwiftUI

class DataService: ObservableObject {
    @Published var containerDataBySystem: [String: [ProcessedContainerData]] = [:]
    @Published var systemDataPointsBySystem: [String: [SystemDataPoint]] = [:]
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let apiService: BeszelAPIService
    private let settingsManager: SettingsManager
    private var cancellables = Set<AnyCancellable>()

    init(instance: Instance, settingsManager: SettingsManager, refreshManager: RefreshManager, instanceManager: InstanceManager) {
        self.settingsManager = settingsManager
        self.apiService = BeszelAPIService(instance: instance, instanceManager: instanceManager)

        settingsManager.objectWillChange
            .sink { [weak self] _ in
                guard let self = self else { return }
                refreshManager.adjustTimer(for: self.settingsManager.selectedTimeRange)
                self.fetchData()
            }
            .store(in: &cancellables)

        instanceManager.objectWillChange
            .dropFirst()
            .sink { [weak self] _ in
                self?.fetchData()
            }
            .store(in: &cancellables)

        refreshManager.$refreshSignal
            .dropFirst()
            .sink { [weak self] _ in
                self?.fetchData()
            }
            .store(in: &cancellables)

        refreshManager.adjustTimer(for: settingsManager.selectedTimeRange)

        fetchData()
    }
    
    private func downsampleStatPoints(_ statPoints: [StatPoint], timeRange: TimeRangeOption) -> [StatPoint] {
        guard !statPoints.isEmpty else { return [] }
        
        let targetCount: Int
        switch timeRange {
        case .lastHour:
            targetCount = 600
        default:
            targetCount = 300
        }

        let minDate = statPoints.min(by: { $0.date < $1.date })?.date ?? Date()
        let maxDate = statPoints.max(by: { $0.date < $1.date })?.date ?? Date()
        let totalDuration = maxDate.timeIntervalSince(minDate)

        let minInterval: TimeInterval
        switch timeRange {
        case .lastHour, .last12Hours:
            minInterval = 30
        case .last24Hours:
            minInterval = 60
        case .last7Days:
            minInterval = 300
        case .last30Days:
            minInterval = 900
        }

        let calculatedInterval = max(minInterval, totalDuration / Double(targetCount))

        return statPoints.downsampled(bucketInterval: calculatedInterval, method: .average)
    }

    func fetchData() {
        Task {
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }

            let systemsToFetch = InstanceManager.shared.systems
            let timeFilter = self.settingsManager.apiFilterString

            guard !systemsToFetch.isEmpty else {
                await MainActor.run {
                    self.systemDataPointsBySystem = [:]
                    self.containerDataBySystem = [:]
                    self.isLoading = false
                }
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

                            let (transformedSystem, transformedContainers) = await MainActor.run {
                                let system = DataProcessor.transformSystem(records: fetchedSystem)
                                let containers = DataProcessor.transform(records: fetchedContainers)
                                return (system, containers)
                            }

                            let downsampledContainers = transformedContainers.map { container in
                                var downsampled = container
                                downsampled.statPoints = self.downsampleStatPoints(container.statPoints, timeRange: self.settingsManager.selectedTimeRange)
                                return downsampled
                            }

                            return (system.id, transformedSystem, downsampledContainers)
                        }
                    }

                    return try await group.reduce(into: ([:], [:])) { (partialResult, taskResult) in
                        partialResult.0[taskResult.systemId] = taskResult.systemData
                        partialResult.1[taskResult.systemId] = taskResult.containerData
                    }
                }

                await MainActor.run {
                    self.systemDataPointsBySystem = finalSystemData
                    self.containerDataBySystem = finalContainerData
                }

            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to fetch data: \(error.localizedDescription)"
                    self.systemDataPointsBySystem = [:]
                    self.containerDataBySystem = [:]
                }
            }

            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
