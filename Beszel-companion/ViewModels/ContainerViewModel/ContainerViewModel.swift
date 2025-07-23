import Foundation
import SwiftUI
import Combine

class ContainerViewModel: BaseViewModel {
    @Published var processedData: [ProcessedContainerData] = []

    private let chartDataManager: ChartDataManager

    init(chartDataManager: ChartDataManager) {
        self.chartDataManager = chartDataManager
        super.init()

        forwardChanges(from: chartDataManager)
        chartDataManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.processedData = self?.chartDataManager.containerData ?? []
            }
            .store(in: &cancellables)

        self.processedData = chartDataManager.containerData
    }

    var sortedData: [ProcessedContainerData] {
        processedData.sorted(by: { $0.name < $1.name })
    }

    func fetchData() async {
        chartDataManager.fetchData()
    }
}
