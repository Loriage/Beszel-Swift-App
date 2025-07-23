import Foundation
import SwiftUI
import Combine

class SystemViewModel: BaseViewModel {
    let chartDataManager: ChartDataManager

    init(chartDataManager: ChartDataManager) {
        self.chartDataManager = chartDataManager
        super.init()

        forwardChanges(from: chartDataManager)
    }
}
