import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class ContainerViewModel {
    private let chartDataManager: ChartDataManager

    init(chartDataManager: ChartDataManager) {
        self.chartDataManager = chartDataManager
    }
    
    var processedData: [ProcessedContainerData] {
        chartDataManager.containerData
    }

    var sortedData: [ProcessedContainerData] {
        processedData.sorted(by: { $0.name < $1.name })
    }

    func fetchData() async {
        await chartDataManager.fetchData()
    }
}
