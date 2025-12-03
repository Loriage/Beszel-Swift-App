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

    private struct SortablePin {
        let resolvedItem: ResolvedPinnedItem
        let systemName: String
        let displayName: String
        let metricName: String
        let serviceName: String
    }

    var filteredAndSortedPins: [ResolvedPinnedItem] {
        let bundle = languageManager.currentBundle
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

        let sortableItems = filteredPins.map { pin -> SortablePin in
            let sysName = chartDataManager.systemName(forSystemID: pin.systemID) ?? ""
            let dispName = pin.item.localizedDisplayName(for: bundle)
            
            return SortablePin(
                resolvedItem: pin,
                systemName: sysName,
                displayName: dispName,
                metricName: pin.item.metricName,
                serviceName: pin.item.serviceName
            )
        }

        let sortedItems: [SortablePin]
        switch sortOption {
        case .bySystem:
            sortedItems = sortableItems.sorted { (lhs, rhs) in
                if lhs.systemName != rhs.systemName {
                    return lhs.systemName < rhs.systemName
                }
                return lhs.displayName < rhs.displayName
            }
        case .byMetric:
            sortedItems = sortableItems.sorted { (lhs, rhs) in
                if lhs.metricName != rhs.metricName {
                    return lhs.metricName < rhs.metricName
                }
                return lhs.displayName < rhs.displayName
            }
        case .byService:
            sortedItems = sortableItems.sorted { (lhs, rhs) in
                if lhs.serviceName != rhs.serviceName {
                    return lhs.serviceName < rhs.serviceName
                }
                return lhs.displayName < rhs.displayName
            }
        }

        let result = sortedItems.map { $0.resolvedItem }
        
        if sortDescending {
            return result.reversed()
        } else {
            return result
        }
    }
}
