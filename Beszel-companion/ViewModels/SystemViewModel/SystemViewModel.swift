import Foundation
import SwiftUI
import Combine

class SystemViewModel: ObservableObject {
    let chartDataManager: ChartDataManager
    private var cancellables = Set<AnyCancellable>()

    init(chartDataManager: ChartDataManager) {
        self.chartDataManager = chartDataManager

        chartDataManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
