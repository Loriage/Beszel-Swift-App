import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class HomeViewModel {
    var isShowingFilterSheet = false
    var searchText = ""
    var sortOption: SortOption = .bySystem
    var sortDescending = false

    let chartDataManager: ChartDataManager
    private let dashboardManager: DashboardManager
    private let languageManager: LanguageManager

    init(chartDataManager: ChartDataManager, dashboardManager: DashboardManager, languageManager: LanguageManager) {
        self.chartDataManager = chartDataManager
        self.dashboardManager = dashboardManager
        self.languageManager = languageManager
    }

    var filteredAndSortedPins: [ResolvedPinnedItem] {
        let bundle: Bundle

        if let path = Bundle.main.path(forResource: languageManager.currentLanguageCode, ofType: "lproj"),
            let specificBundle = Bundle(path: path) {
            bundle = specificBundle
        } else {
            bundle = .main
        }
        
        let pins = dashboardManager.allPinsForActiveInstance
        
        let filteredPins: [ResolvedPinnedItem]
        if searchText.isEmpty {
            filteredPins = pins
        } else {
            filteredPins = pins.filter { resolvedItem in
                let systemName = chartDataManager.systemName(forSystemID: resolvedItem.systemID) ?? ""
                let itemName = resolvedItem.item.localizedDisplayName(for: bundle)
                
                return systemName.localizedCaseInsensitiveContains(searchText) ||
                itemName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        var sortedPins: [ResolvedPinnedItem]
        switch sortOption {
        case .bySystem:
            sortedPins = filteredPins.sorted { (lhs, rhs) in
                let lhsSystemName = chartDataManager.systemName(forSystemID: lhs.systemID) ?? ""
                let rhsSystemName = chartDataManager.systemName(forSystemID: rhs.systemID) ?? ""
                if lhsSystemName != rhsSystemName {
                    return lhsSystemName < rhsSystemName
                }
                return lhs.item.localizedDisplayName(for: bundle) < rhs.item.localizedDisplayName(for: bundle)
            }
        case .byMetric:
            sortedPins = filteredPins.sorted { lhs, rhs in
                if lhs.item.metricName != rhs.item.metricName {
                    return lhs.item.metricName < rhs.item.metricName
                }
                return lhs.item.localizedDisplayName(for: bundle) < rhs.item.localizedDisplayName(for: bundle)
            }
        case .byService:
            sortedPins = filteredPins.sorted { lhs, rhs in
                if lhs.item.serviceName != rhs.item.serviceName {
                    return lhs.item.serviceName < rhs.item.serviceName
                }
                return lhs.item.localizedDisplayName(for: bundle) < rhs.item.localizedDisplayName(for: bundle)
            }
        }
        
        if sortDescending {
            return sortedPins.reversed()
        } else {
            return sortedPins
        }
    }
}
