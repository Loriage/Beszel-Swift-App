import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class SystemViewModel {
    let chartDataManager: ChartDataManager

    init(chartDataManager: ChartDataManager) {
        self.chartDataManager = chartDataManager
    }
}
