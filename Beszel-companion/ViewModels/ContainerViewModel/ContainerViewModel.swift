import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class ContainerViewModel {
    // Avec @Observable, les propriétés calculées sont observées si elles dépendent d'autres propriétés observées.
    // Ici on expose directement les données du chartDataManager.
    
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
        chartDataManager.fetchData()
    }
}
