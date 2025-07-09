import Foundation
import Combine
import SwiftUI

class MainViewModel: ObservableObject {
    @Published var containerDataBySystem: [String: [ProcessedContainerData]] = [:]
    @Published var systemDataPointsBySystem: [String: [SystemDataPoint]] = [:]
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    private let apiService: BeszelAPIService
    private let settingsManager: SettingsManager
    private let instanceManager: InstanceManager
    private var cancellables = Set<AnyCancellable>()
    
    init(instance: Instance, settingsManager: SettingsManager, refreshManager: RefreshManager, instanceManager: InstanceManager) {
        self.settingsManager = settingsManager
        self.instanceManager = instanceManager
        
        let password = InstanceManager.shared.loadPassword(for: instance) ?? ""
        self.apiService = BeszelAPIService(url: instance.url, email: instance.email, password: password)
        
        settingsManager.objectWillChange
            .sink { [weak self] _ in
                guard let self = self else { return }
                refreshManager.adjustTimer(for: self.settingsManager.selectedTimeRange)
                self.fetchData()
            }
            .store(in: &cancellables)
        
        instanceManager.$activeSystem
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

    func fetchData() {
        Task {
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }

            let systemsToFetch = instanceManager.systems
            
            guard !systemsToFetch.isEmpty else {
                await MainActor.run {
                    self.systemDataPointsBySystem = [:]
                    self.containerDataBySystem = [:]
                    self.isLoading = false
                }
                return
            }

            await withTaskGroup(of: (systemId: String, systemData: [SystemDataPoint], containerData: [ProcessedContainerData]).self) { group in
                for system in systemsToFetch {
                    group.addTask {
                        let systemFilter = "system = '\(system.id)'"
                        var filters: [String] = [systemFilter]
                        
                        if let timeFilter = await self.settingsManager.apiFilterString {
                            filters.append(timeFilter)
                        }
                        let finalFilter = "(\(filters.joined(separator: " && ")))"
                        
                        do {
                            async let containerRecords = self.apiService.fetchMonitors(filter: finalFilter)
                            async let systemRecords = self.apiService.fetchSystemStats(filter: finalFilter)
                            
                            let fetchedContainers = try await containerRecords
                            let fetchedSystem = try await systemRecords
                            
                            let transformedSystem = await DataProcessor.transformSystem(records: fetchedSystem)
                            let transformedContainers = await DataProcessor.transform(records: fetchedContainers)
                            
                            return (system.id, transformedSystem, transformedContainers)
                        } catch {
                            return (system.id, [], [])
                        }
                    }
                }
                
                var tempSystemData: [String: [SystemDataPoint]] = [:]
                var tempContainerData: [String: [ProcessedContainerData]] = [:]
                
                for await result in group {
                    tempSystemData[result.systemId] = result.systemData
                    tempContainerData[result.systemId] = result.containerData
                }
                
                await MainActor.run {
                    self.systemDataPointsBySystem = tempSystemData
                    self.containerDataBySystem = tempContainerData
                }
            }
            
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
