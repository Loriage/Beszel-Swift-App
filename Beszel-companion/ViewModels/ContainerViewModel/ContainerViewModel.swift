import Foundation
import SwiftUI
import Combine

class ContainerViewModel: ObservableObject {
    @Published var processedData: [ProcessedContainerData] = []

    private let chartDataManager: ChartDataManager
    private var cancellables = Set<AnyCancellable>()

    init(chartDataManager: ChartDataManager) {
        self.chartDataManager = chartDataManager

        chartDataManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.processedData = chartDataManager.containerData
                self?.objectWillChange.send()
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
