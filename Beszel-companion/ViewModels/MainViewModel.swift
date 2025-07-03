import Foundation
import Combine
import SwiftUI

class MainViewModel: ObservableObject {
    @Published var containerData: [ProcessedContainerData] = []
    @Published var systemDataPoints: [SystemDataPoint] = []
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

        fetchData()
    }

    func fetchData() {
        guard let activeSystem = instanceManager.activeSystem else {
            self.containerData = []
            self.systemDataPoints = []
            return
        }

        Task {
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            let systemFilter = "system = '\(activeSystem.id)'"
            var filters: [String] = [systemFilter]

            if let timeFilter = settingsManager.apiFilterString {
                filters.append(timeFilter)
            }

            let rawFilterExpression = filters.joined(separator: " && ")
            let finalFilter = "(\(rawFilterExpression))"

            do {
                async let containerRecords = apiService.fetchMonitors(filter: finalFilter)
                async let systemRecords = apiService.fetchSystemStats(filter: finalFilter)

                let fetchedContainers = try await containerRecords
                let fetchedSystem = try await systemRecords
                
                await MainActor.run {
                    // todo: average values selector to smooth curves
                    // let transformedData = DataProcessor.transformSystem(records: fetchedSystem)
                    // let smoothedData = DataProcessor.applyMovingAverage(to: transformedData, windowSize: 3)

                    self.containerData = DataProcessor.transform(records: fetchedContainers)
                    self.systemDataPoints = DataProcessor.transformSystem(records: fetchedSystem)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
            
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
