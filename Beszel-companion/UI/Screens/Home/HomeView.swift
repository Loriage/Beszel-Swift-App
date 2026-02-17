import SwiftUI
import Charts

struct HomeView: View {
    @Environment(BeszelStore.self) var store
    @Environment(DashboardManager.self) var dashboardManager
    @Environment(SettingsManager.self) var settingsManager
    @Environment(LanguageManager.self) var languageManager
    @Environment(InstanceManager.self) var instanceManager
    
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

        var isSystemInfo: Bool {
            resolvedItem.item == .systemInfo
        }
    }

    /// Returns comparison result for systemInfo priority (systemInfo items always come first)
    private func compareSystemInfoPriority(_ lhs: SortablePin, _ rhs: SortablePin) -> ComparisonResult? {
        if lhs.isSystemInfo && !rhs.isSystemInfo { return .orderedAscending }
        if !lhs.isSystemInfo && rhs.isSystemInfo { return .orderedDescending }
        return nil
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
                if let priority = compareSystemInfoPriority(lhs, rhs) {
                    return priority == .orderedAscending
                }
                if lhs.systemName != rhs.systemName {
                    return lhs.systemName < rhs.systemName
                }
                return lhs.displayName < rhs.displayName
            }
        case .byMetric:
            sortedItems = sortableItems.sorted { (lhs, rhs) in
                if let priority = compareSystemInfoPriority(lhs, rhs) {
                    return priority == .orderedAscending
                }
                if lhs.metricName != rhs.metricName {
                    return lhs.metricName < rhs.metricName
                }
                return lhs.displayName < rhs.displayName
            }
        case .byService:
            sortedItems = sortableItems.sorted { (lhs, rhs) in
                if let priority = compareSystemInfoPriority(lhs, rhs) {
                    return priority == .orderedAscending
                }
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
                ScreenHeaderView(
                    title: "home.title",
                    subtitle: store.isLoading ? "switcher.loading" : "home.subtitle"
                )
                
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
            .padding(.bottom, 24)
        }
        .groupBoxStyle(CardGroupBoxStyle())
        .overlay {
            if store.isLoading && dashboardManager.allPinsForActiveInstance.isEmpty {
                ProgressView()
            } else if let errorMessage = store.errorMessage, dashboardManager.allPinsForActiveInstance.isEmpty {
                ContentUnavailableView {
                    Label("common.error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("common.retry") {
                        store.clearAuthenticationError()
                        Task {
                            await store.fetchData()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } else if dashboardManager.allPinsForActiveInstance.isEmpty {
                ContentUnavailableView {
                    Label("home.empty.title", systemImage: "pin.slash")
                } description: {
                    Text("home.empty.message")
                }
            }
        }
        .refreshable {
            await store.fetchData()
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
        case .systemInfo:
            if let system = instanceManager.systems.first(where: { $0.id == resolvedItem.systemID }),
               let stats = store.latestStats(for: resolvedItem.systemID)?.stats {
                SystemSummaryCard(
                    system: system,
                    systemInfo: system.info,
                    stats: stats,
                    systemName: system.name,
                    status: system.status,
                    isPinned: store.isPinned(.systemInfo, onSystem: resolvedItem.systemID),
                    onPinToggle: { store.togglePin(for: .systemInfo, onSystem: resolvedItem.systemID) }
                )
            }
        case .systemCPU:
            SystemMetricChartView(
                title: "chart.cpuUsage",
                xAxisFormat: store.xAxisFormat,
                dataPoints: systemData,
                valueKeyPath: \.cpu,
                color: .blue,
                systemName: systemName,
                isPinned: store.isPinned(.systemCPU, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemCPU, onSystem: resolvedItem.systemID) }
            )
        case .systemMemory:
            SystemMetricChartView(
                title: "chart.memoryUsage",
                xAxisFormat: store.xAxisFormat,
                dataPoints: systemData,
                valueKeyPath: \.memoryPercent,
                color: .green,
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
        case .systemDiskIO:
            SystemDiskIOChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemDiskIO, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemDiskIO, onSystem: resolvedItem.systemID) }
            )
        case .systemDiskUsage:
            SystemDiskUsageChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemDiskUsage, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemDiskUsage, onSystem: resolvedItem.systemID) }
            )
        case .systemBandwidth:
            SystemBandwidthChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemBandwidth, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemBandwidth, onSystem: resolvedItem.systemID) }
            )
        case .systemLoadAverage:
            SystemLoadChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemLoadAverage, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemLoadAverage, onSystem: resolvedItem.systemID) }
            )
        case .systemSwap:
            SystemSwapChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemSwap, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemSwap, onSystem: resolvedItem.systemID) }
            )
        case .systemGPU:
            SystemGPUChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemGPU, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemGPU, onSystem: resolvedItem.systemID) }
            )
        case .systemNetworkInterfaces:
            SystemNetworkInterfacesChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemNetworkInterfaces, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemNetworkInterfaces, onSystem: resolvedItem.systemID) }
            )
        case .systemExtraFilesystems:
            SystemExtraFilesystemsChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemExtraFilesystems, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemExtraFilesystems, onSystem: resolvedItem.systemID) }
            )
        case .containerCPU(let name):
            if let container = containerData.first(where: { $0.id == name }) {
                ContainerMetricChartView(
                    titleKey: "chart.container.cpuUsage.percent",
                    containerName: container.name,
                    xAxisFormat: store.xAxisFormat,
                    container: container,
                    valueKeyPath: \.cpu,
                    color: .blue,
                    systemName: systemName,
                    isPinned: store.isPinned(.containerCPU(name: container.name), onSystem: resolvedItem.systemID),
                    onPinToggle: { store.togglePin(for: .containerCPU(name: container.name), onSystem: resolvedItem.systemID) }
                )
            }
        case .containerMemory(let name):
            if let container = containerData.first(where: { $0.id == name }) {
                ContainerMetricChartView(
                    titleKey: "chart.container.memoryUsage.bytes",
                    containerName: container.name,
                    xAxisFormat: store.xAxisFormat,
                    container: container,
                    valueKeyPath: \.memory,
                    color: .green,
                    systemName: systemName,
                    isPinned: store.isPinned(.containerMemory(name: container.name), onSystem: resolvedItem.systemID),
                    onPinToggle: { store.togglePin(for: .containerMemory(name: container.name), onSystem: resolvedItem.systemID) }
                )
            }
        case .stackedContainerCPU:
            let (stacked, domain) = store.getStackedCpuData(for: resolvedItem.systemID)
            StackedCpuChartView(
                stackedData: stacked,
                domain: domain,
                systemID: resolvedItem.systemID,
                systemName: systemName
            )
        case .stackedContainerMemory:
            let (stacked, domain) = store.getStackedMemoryData(for: resolvedItem.systemID)
            StackedMemoryChartView(
                stackedData: stacked,
                domain: domain,
                systemID: resolvedItem.systemID,
                systemName: systemName
            )
        case .stackedContainerNetwork:
            let (stacked, domain) = store.getStackedNetworkData(for: resolvedItem.systemID)
            StackedNetworkChartView(
                stackedData: stacked,
                domain: domain,
                systemID: resolvedItem.systemID,
                systemName: systemName
            )
        }
    }
}
