import SwiftUI
import Charts

enum SortOption: String, CaseIterable, Identifiable {
    case bySystem = "Par Système"
    case byMetric = "Par Métrique"
    case byService = "Par Service"

    var id: String { self.rawValue }
}

struct HomeView: View {
    @EnvironmentObject var dashboardManager: DashboardManager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var instanceManager: InstanceManager

    @ObservedObject var viewModel: MainViewModel
    
    @State private var searchText = ""
    @State private var sortOption: SortOption = .bySystem

    private var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }

    private var hasTemperatureData: Bool {
        viewModel.systemDataPointsBySystem.values.contains { dataPointsArray in
            dataPointsArray.contains { !$0.temperatures.isEmpty }
        }
    }

    private var filteredAndSortedPins: [ResolvedPinnedItem] {
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

        switch sortOption {
        case .bySystem:
            return filteredPins.sorted { (lhs, rhs) in
                let lhsSystemName = instanceManager.systems.first { $0.id == lhs.systemID }?.name ?? ""
                let rhsSystemName = instanceManager.systems.first { $0.id == rhs.systemID }?.name ?? ""
                if lhsSystemName != rhsSystemName {
                    return lhsSystemName < rhsSystemName
                }
                return lhs.item.displayName < rhs.item.displayName
            }
        case .byMetric:
            return filteredPins.sorted { lhs, rhs in
                if lhs.item.metricName != rhs.item.metricName {
                    return lhs.item.metricName < rhs.item.metricName
                }
                return lhs.item.displayName < rhs.item.displayName
            }
        case .byService:
            return filteredPins.sorted { lhs, rhs in
                if lhs.item.serviceName != rhs.item.serviceName {
                    return lhs.item.serviceName < rhs.item.serviceName
                }
                return lhs.item.displayName < rhs.item.displayName
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading) {
                    Text("home.title")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("home.subtitle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                if dashboardManager.allPinsForActiveInstance.isEmpty {
                    emptyStateView
                } else {
                    HStack {
                        TextField("Rechercher...", text: $searchText)
                            .padding(8)
                            .padding(.leading, 24)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .overlay(
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.gray)
                                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 8)
                                }
                            )
                        
                        Menu {
                            Picker("Trier par", selection: $sortOption) {
                                ForEach(SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 24) {
                        ForEach(filteredAndSortedPins) { resolvedItem in
                            pinnedItemView(for: resolvedItem)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack (alignment: .center, spacing: 8) {
            Image(systemName: "pin.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("home.empty.title")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 8)
            Text("home.empty.message")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.top, 80)
    }

    @ViewBuilder
    private func pinnedItemView(for resolvedItem: ResolvedPinnedItem) -> some View {
        let systemData = viewModel.systemDataPointsBySystem[resolvedItem.systemID] ?? []
        let containerData = viewModel.containerDataBySystem[resolvedItem.systemID] ?? []
        let systemName = instanceManager.systems.first { $0.id == resolvedItem.systemID }?.name
        
        switch resolvedItem.item {
        case .systemCPU:
            SystemCpuChartView(
                xAxisFormat: xAxisFormat,
                dataPoints: systemData,
                systemName: systemName,
                isPinned: dashboardManager.isPinned(.systemCPU),
                onPinToggle: { dashboardManager.togglePin(for: .systemCPU) }
            )
        case .systemMemory:
            SystemMemoryChartView(
                xAxisFormat: xAxisFormat,
                dataPoints: systemData,
                systemName: systemName,
                isPinned: dashboardManager.isPinned(.systemMemory),
                onPinToggle: { dashboardManager.togglePin(for: .systemMemory) }
            )
        case .systemTemperature:
            if hasTemperatureData {
                SystemTemperatureChartView(
                    xAxisFormat: xAxisFormat,
                    dataPoints: systemData,
                    systemName: systemName,
                    isPinned: dashboardManager.isPinned(.systemTemperature),
                    onPinToggle: { dashboardManager.togglePin(for: .systemTemperature) }
                )
            }
        case .containerCPU(let name):
            if let container = containerData.first(where: { $0.id == name }) {
                ContainerCpuChartView(
                    xAxisFormat: xAxisFormat,
                    container: container,
                    systemName: systemName,
                    isPinned: dashboardManager.isPinned(.containerCPU(name: container.name)),
                    onPinToggle: { dashboardManager.togglePin(for: .containerCPU(name: container.name)) }
                )
            }
        case .containerMemory(let name):
            if let container = containerData.first(where: { $0.id == name }) {
                ContainerMemoryChartView(
                    xAxisFormat: xAxisFormat,
                    container: container,
                    systemName: systemName,
                    isPinned: dashboardManager.isPinned(.containerMemory(name: container.name)),
                    onPinToggle: { dashboardManager.togglePin(for: .containerMemory(name: container.name)) }
                )
            }
        }
    }
}
