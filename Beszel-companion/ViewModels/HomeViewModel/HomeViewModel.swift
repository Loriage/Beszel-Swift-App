import Foundation
import SwiftUI
import Combine

enum SortOption: String, CaseIterable, Identifiable {
    case bySystem = "filter.bySystem"
    case byMetric = "filter.byMetric"
    case byService = "filter.byService"

    var id: String { self.rawValue }
}

class HomeViewModel: ObservableObject {
    @Published var isShowingFilterSheet = false
    @Published var searchText = ""
    @Published var sortOption: SortOption = .bySystem
    @Published var sortDescending = false

    let chartDataManager: ChartDataManager
    private let dashboardManager: DashboardManager
    private var cancellables = Set<AnyCancellable>()

    init(chartDataManager: ChartDataManager, dashboardManager: DashboardManager) {
        self.chartDataManager = chartDataManager
        self.dashboardManager = dashboardManager

        chartDataManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        dashboardManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var filteredAndSortedPins: [ResolvedPinnedItem] {
        let pins = dashboardManager.allPinsForActiveInstance
        
        let filteredPins: [ResolvedPinnedItem]
        if searchText.isEmpty {
            filteredPins = pins
        } else {
            filteredPins = pins.filter { resolvedItem in
                let systemName = chartDataManager.systemName(forSystemID: resolvedItem.systemID) ?? ""
                let itemName = resolvedItem.item.displayName
                
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
                return lhs.item.displayName < rhs.item.displayName
            }
        case .byMetric:
            sortedPins = filteredPins.sorted { lhs, rhs in
                if lhs.item.metricName != rhs.item.metricName {
                    return lhs.item.metricName < rhs.item.metricName
                }
                return lhs.item.displayName < rhs.item.displayName
            }
        case .byService:
            sortedPins = filteredPins.sorted { lhs, rhs in
                if lhs.item.serviceName != rhs.item.serviceName {
                    return lhs.item.serviceName < rhs.item.serviceName
                }
                return lhs.item.displayName < rhs.item.displayName
            }
        }
        
        if sortDescending {
            return sortedPins.reversed()
        } else {
            return sortedPins
        }
    }
}
