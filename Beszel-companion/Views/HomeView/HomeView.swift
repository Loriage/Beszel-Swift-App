import SwiftUI
import Charts

struct HomeView: View {
    @Environment(BeszelStore.self) var store
    @Environment(DashboardManager.self) var dashboardManager
    @Environment(SettingsManager.self) var settingsManager
    @Environment(LanguageManager.self) var languageManager
    
    @State private var isShowingFilterSheet = false
    @State private var searchText = ""
    @State private var sortOption: SortOption = .bySystem
    @State private var sortDescending = false
    
    private struct SortablePin {
        let resolvedItem: ResolvedPinnedItem
        let systemName: String
        let displayName: String
        let metricName: String
        let serviceName: String
    }
    
    private var filteredAndSortedPins: [ResolvedPinnedItem] {
        let bundle = languageManager.currentBundle
        let pins = dashboardManager.allPinsForActiveInstance
        
        let filteredPins: [ResolvedPinnedItem]
        if searchText.isEmpty {
            filteredPins = pins
        } else {
            filteredPins = pins.filter { resolvedItem in
                let systemName = store.systemName(forSystemID: resolvedItem.systemID) ?? ""
                let itemName = resolvedItem.item.localizedDisplayName(for: bundle)
                return systemName.localizedCaseInsensitiveContains(searchText) ||
                itemName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        let sortableItems = filteredPins.map { pin -> SortablePin in
            let sysName = store.systemName(forSystemID: pin.systemID) ?? ""
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
        return sortDescending ? result.reversed() : result
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeaderView(title: "home.title", subtitle: "home.subtitle")
                
                if store.isLoading {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .padding(.horizontal)
                }
                
                HStack {
                    TextField("dashboard.searchPlaceholder", text: $searchText)
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
                    Button(action: {
                        isShowingFilterSheet = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title)
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
        .overlay {
            if dashboardManager.allPinsForActiveInstance.isEmpty {
                ContentUnavailableView {
                    Label("home.empty.title", systemImage: "pin.slash")
                } description: {
                    Text("home.empty.message")
                }
            }
        }
        .sheet(isPresented: $isShowingFilterSheet) {
            FilterView(
                sortOption: $sortOption,
                sortDescending: $sortDescending
            )
        }
    }
    
    @ViewBuilder
    private func pinnedItemView(for resolvedItem: ResolvedPinnedItem) -> some View {
        let systemData = store.systemData(forSystemID: resolvedItem.systemID)
        let containerData = store.containerData(forSystemID: resolvedItem.systemID)
        let systemName = store.systemName(forSystemID: resolvedItem.systemID)
        
        switch resolvedItem.item {
        case .systemCPU:
            SystemCpuChartView(
                xAxisFormat: store.xAxisFormat,
                dataPoints: systemData,
                systemName: systemName,
                isPinned: store.isPinned(.systemCPU, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemCPU, onSystem: resolvedItem.systemID) }
            )
        case .systemMemory:
            SystemMemoryChartView(
                xAxisFormat: store.xAxisFormat,
                dataPoints: systemData,
                systemName: systemName,
                isPinned: store.isPinned(.systemMemory, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemMemory, onSystem: resolvedItem.systemID) }
            )
        case .systemTemperature:
            SystemTemperatureChartView(
                xAxisFormat: store.xAxisFormat,
                dataPoints: systemData,
                systemName: systemName,
                isPinned: store.isPinned(.systemTemperature, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemTemperature, onSystem: resolvedItem.systemID) }
            )
        case .containerCPU(let name):
            if let container = containerData.first(where: { $0.id == name }) {
                ContainerCpuChartView(
                    xAxisFormat: store.xAxisFormat,
                    container: container,
                    systemName: systemName,
                    isPinned: store.isPinned(.containerCPU(name: container.name), onSystem: resolvedItem.systemID),
                    onPinToggle: { store.togglePin(for: .containerCPU(name: container.name), onSystem: resolvedItem.systemID) }
                )
            }
        case .containerMemory(let name):
            if let container = containerData.first(where: { $0.id == name }) {
                ContainerMemoryChartView(
                    xAxisFormat: store.xAxisFormat,
                    container: container,
                    systemName: systemName,
                    isPinned: store.isPinned(.containerMemory(name: container.name), onSystem: resolvedItem.systemID),
                    onPinToggle: { store.togglePin(for: .containerMemory(name: container.name), onSystem: resolvedItem.systemID) }
                )
            }
        case .stackedContainerCPU:
            StackedCpuChartView(
                settingsManager: settingsManager,
                processedData: containerData,
                systemID: resolvedItem.systemID,
                systemName: systemName
            )
        case .stackedContainerMemory:
            StackedMemoryChartView(
                settingsManager: settingsManager,
                processedData: containerData,
                systemID: resolvedItem.systemID,
                systemName: systemName
            )
        }
    }
}
