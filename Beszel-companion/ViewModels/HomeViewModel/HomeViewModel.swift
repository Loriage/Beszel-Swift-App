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

    private let dashboardManager: DashboardManager
    private let settingsManager: SettingsManager
    private let instanceManager: InstanceManager
    private let mainViewModel: MainViewModel
    private var cancellables = Set<AnyCancellable>()

    init(dashboardManager: DashboardManager, settingsManager: SettingsManager, instanceManager: InstanceManager, mainViewModel: MainViewModel) {
        self.dashboardManager = dashboardManager
        self.settingsManager = settingsManager
        self.instanceManager = instanceManager
        self.mainViewModel = mainViewModel

        mainViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        dashboardManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        instanceManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }

    var hasTemperatureData: Bool {
        mainViewModel.systemDataPointsBySystem.values.contains { dataPointsArray in
            dataPointsArray.contains { !$0.temperatures.isEmpty }
        }
    }

    var filteredAndSortedPins: [ResolvedPinnedItem] {
        let pins = dashboardManager.allPinsForActiveInstance
        
        let filteredPins: [ResolvedPinnedItem]
        if searchText.isEmpty {
            filteredPins = pins
        } else {
            filteredPins = pins.filter { resolvedItem in
                let systemName = instanceManager.systems.first { $0.id == resolvedItem.systemID }?.name ?? ""
                let itemName = resolvedItem.item.displayName
                
                return systemName.localizedCaseInsensitiveContains(searchText) ||
                itemName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        var sortedPins: [ResolvedPinnedItem]
        switch sortOption {
        case .bySystem:
            sortedPins = filteredPins.sorted { (lhs, rhs) in
                let lhsSystemName = instanceManager.systems.first { $0.id == lhs.systemID }?.name ?? ""
                let rhsSystemName = instanceManager.systems.first { $0.id == rhs.systemID }?.name ?? ""
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

    func fetchData() {
        mainViewModel.fetchData()
    }

    func systemData(for resolvedItem: ResolvedPinnedItem) -> [SystemDataPoint] {
        mainViewModel.systemDataPointsBySystem[resolvedItem.systemID] ?? []
    }

    func containerData(for resolvedItem: ResolvedPinnedItem) -> [ProcessedContainerData] {
        mainViewModel.containerDataBySystem[resolvedItem.systemID] ?? []
    }

    func systemName(for resolvedItem: ResolvedPinnedItem) -> String? {
        instanceManager.systems.first { $0.id == resolvedItem.systemID }?.name
    }

    func isPinned(_ item: PinnedItem) -> Bool {
        dashboardManager.isPinned(item)
    }

    func togglePin(for item: PinnedItem) {
        dashboardManager.togglePin(for: item)
    }
}
