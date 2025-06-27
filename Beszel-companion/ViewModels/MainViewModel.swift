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
    private var cancellables = Set<AnyCancellable>()

    init(instance: Instance, settingsManager: SettingsManager, refreshManager: RefreshManager) {
        self.settingsManager = settingsManager
        
        let password = InstanceManager.shared.loadPassword(for: instance) ?? ""
        self.apiService = BeszelAPIService(url: instance.url, email: instance.email, password: password)

        settingsManager.objectWillChange
            .sink { [weak self] _ in
                guard let self = self else { return }
                refreshManager.adjustTimer(for: self.settingsManager.selectedTimeRange)
                self.fetchData()
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
        Task {
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            let filter = settingsManager.apiFilterString

            do {
                async let containerRecords = apiService.fetchMonitors(filter: filter)
                async let systemRecords = apiService.fetchSystemStats(filter: filter)

                let fetchedContainers = try await containerRecords
                let fetchedSystem = try await systemRecords
                
                await MainActor.run {
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
