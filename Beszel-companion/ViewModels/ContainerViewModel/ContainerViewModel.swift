import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class ContainerViewModel {
    private let chartDataManager: ChartDataManager

    var sortedData: [ProcessedContainerData] = []

    init(chartDataManager: ChartDataManager) {
        self.chartDataManager = chartDataManager
        updateSortedData()
    }

    var processedData: [ProcessedContainerData] {
        chartDataManager.containerData
    }

    func fetchData() async {
        await chartDataManager.fetchData()
        updateSortedData()
    }

    func updateSortedData() {
        self.sortedData = processedData.sorted(by: { $0.name < $1.name })
    }
}
