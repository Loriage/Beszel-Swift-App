import SwiftUI
import Charts

struct HomeView: View {
    @Environment(BeszelStore.self) var store
    @Environment(DashboardManager.self) var dashboardManager
    @Environment(SettingsManager.self) var settingsManager
    @Environment(LanguageManager.self) var languageManager
    @Environment(InstanceManager.self) var instanceManager

    let onSettingsTap: () -> Void
    
    @State private var presentedSheet: HomeSheet?
    @State private var searchText = ""

    private var activeInstanceID: String? {
        instanceManager.activeInstance?.id.uuidString
    }

    private var systemNames: [String: String] {
        instanceManager.systems.reduce(into: [:]) { $0[$1.id] = $1.name }
    }

    private var sortedPins: [ResolvedPinnedItem] {
        guard let instanceID = activeInstanceID else { return [] }
        return dashboardManager[layoutFor: instanceID].sortedPins(
            dashboardManager.pins(forInstanceID: instanceID),
            systemNames: systemNames,
            bundle: languageManager.currentBundle
        )
    }
    
    var body: some View {
        @Bindable var dashboardManager = dashboardManager
        let pins = sortedPins
        let names = systemNames
        let bundle = languageManager.currentBundle
        let visiblePins = pins.filter { pin in
            searchText.isEmpty ||
            (names[pin.systemID] ?? "").localizedCaseInsensitiveContains(searchText) ||
            pin.item.localizedDisplayName(for: bundle).localizedCaseInsensitiveContains(searchText)
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HomePinnedChartControls(
                    searchText: $searchText,
                    onFilter: {
                        if let instanceID = activeInstanceID { presentedSheet = .filters(instanceID) }
                    }
                )
                .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                    ForEach(visiblePins) { resolvedItem in
                        pinnedItemView(for: resolvedItem)
                    }
                }
                .environment(\.chartXDomain, store.xDomain)
                .environment(\.chartShowXGridLines, settingsManager.showChartGridLines)
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("home.title")
        .monitoringNavigationSubtitle("home.subtitle")
        .navigationBarTitleDisplayMode(.large)
        .withMainToolbar(
            instanceManager: instanceManager,
            showsSystemSwitcher: false,
            canReorder: pins.count > 1,
            onReorderTap: beginReordering,
            onSettingsTap: onSettingsTap
        )
        .monitoringScreenBackground()
        .groupBoxStyle(CardGroupBoxStyle())
        .overlay {
            if store.isLoading && pins.isEmpty {
                MonitoringStateView(state: .loading("switcher.loading"))
            } else if let errorMessage = store.errorMessage, pins.isEmpty {
                MonitoringStateView(state: .failure(errorMessage)) {
                    store.clearAuthenticationError()
                    Task {
                        await store.fetchData()
                    }
                }
            } else if pins.isEmpty {
                MonitoringStateView(
                    state: .empty(
                        title: "home.empty.title",
                        message: "home.empty.message",
                        systemImage: "pin.slash"
                    )
                )
            } else if visiblePins.isEmpty {
                MonitoringStateView(
                    state: .empty(
                        title: "common.noResults.title",
                        message: "common.noResults.message",
                        systemImage: "magnifyingglass"
                    )
                )
            }
        }
        .refreshable {
            await store.fetchData()
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .filters(let instanceID):
                FilterView(layout: $dashboardManager[layoutFor: instanceID])
            case .reorder(let instanceID):
                PinnedChartsOrderView(instanceID: instanceID, systemNames: names)
            }
        }
    }

    private func beginReordering() {
        guard let instanceID = activeInstanceID else { return }
        // Start from the full displayed order, never the search-filtered subset.
        dashboardManager.setPinOrder(sortedPins, forInstanceID: instanceID)
        presentedSheet = .reorder(instanceID)
    }

    private enum HomeSheet: Identifiable {
        case filters(String)
        case reorder(String)

        var id: String {
            switch self {
            case .filters(let instanceID): "filters-\(instanceID)"
            case .reorder(let instanceID): "reorder-\(instanceID)"
            }
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
                subtitle: "chart.cpuUsage.subtitle",
                unit: "%",
                systemName: systemName,
                isPinned: store.isPinned(.systemCPU, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemCPU, onSystem: resolvedItem.systemID) }
            )
        case .systemCPUTimeBreakdown:
            SystemCpuTimeBreakdownChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemCPUTimeBreakdown, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemCPUTimeBreakdown, onSystem: resolvedItem.systemID) }
            )
        case .systemCPUCores:
            SystemCpuCoresChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemCPUCores, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemCPUCores, onSystem: resolvedItem.systemID) }
            )
        case .systemMemory:
            SystemMetricChartView(
                title: "chart.memoryUsage",
                xAxisFormat: store.xAxisFormat,
                dataPoints: systemData,
                valueKeyPath: \.memoryPercent,
                color: .green,
                subtitle: "chart.memoryUsage.subtitle",
                unit: "%",
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
        case .systemBattery, .systemFans:
            SensorHistoryChart(
                history: resolvedItem.item == .systemBattery
                    ? store.sensorCharts(forSystemID: resolvedItem.systemID).battery
                    : store.sensorCharts(forSystemID: resolvedItem.systemID).fans,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(resolvedItem.item, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: resolvedItem.item, onSystem: resolvedItem.systemID) }
            )
        case .systemDiskIO:
            SystemDiskIOChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                diskName: instanceManager.systems.first { $0.id == resolvedItem.systemID }?.info?.rdn,
                isPinned: store.isPinned(.systemDiskIO, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemDiskIO, onSystem: resolvedItem.systemID) }
            )
        case .systemDiskIOUtilization:
            SystemDiskIOUtilizationChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemDiskIOUtilization, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemDiskIOUtilization, onSystem: resolvedItem.systemID) }
            )
        case .systemDiskIOTimes:
            SystemDiskIOTimesChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemDiskIOTimes, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemDiskIOTimes, onSystem: resolvedItem.systemID) }
            )
        case .systemDiskAwait:
            SystemDiskAwaitChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemDiskAwait, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemDiskAwait, onSystem: resolvedItem.systemID) }
            )
        case .systemDiskIOQueueDepth:
            SystemDiskIOQueueDepthChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemDiskIOQueueDepth, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemDiskIOQueueDepth, onSystem: resolvedItem.systemID) }
            )
        case .systemDiskUsage:
            SystemDiskUsageChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                diskName: instanceManager.systems.first { $0.id == resolvedItem.systemID }?.info?.rdn,
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
        case .systemBandwidthDownload:
            BandwidthDownloadChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemBandwidthDownload, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemBandwidthDownload, onSystem: resolvedItem.systemID) }
            )
        case .systemBandwidthUpload:
            BandwidthUploadChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemBandwidthUpload, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemBandwidthUpload, onSystem: resolvedItem.systemID) }
            )
        case .systemBandwidthCumulativeDownload:
            BandwidthCumulativeDownloadChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemBandwidthCumulativeDownload, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemBandwidthCumulativeDownload, onSystem: resolvedItem.systemID) }
            )
        case .systemBandwidthCumulativeUpload:
            BandwidthCumulativeUploadChartView(
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.systemBandwidthCumulativeUpload, onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .systemBandwidthCumulativeUpload, onSystem: resolvedItem.systemID) }
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
        case .extraDiskUsage(let name):
            ExtraDiskUsageChartView(
                diskName: name,
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.extraDiskUsage(name: name), onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .extraDiskUsage(name: name), onSystem: resolvedItem.systemID) }
            )
        case .extraDiskIO(let name):
            ExtraDiskIOChartView(
                diskName: name,
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.extraDiskIO(name: name), onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .extraDiskIO(name: name), onSystem: resolvedItem.systemID) }
            )
        case .extraDiskIOUtilization(let name):
            ExtraDiskIOUtilizationChartView(
                diskName: name,
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.extraDiskIOUtilization(name: name), onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .extraDiskIOUtilization(name: name), onSystem: resolvedItem.systemID) }
            )
        case .extraDiskIOTimes(let name):
            ExtraDiskIOTimesChartView(
                diskName: name,
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.extraDiskIOTimes(name: name), onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .extraDiskIOTimes(name: name), onSystem: resolvedItem.systemID) }
            )
        case .extraDiskAwait(let name):
            ExtraDiskAwaitChartView(
                diskName: name,
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.extraDiskAwait(name: name), onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .extraDiskAwait(name: name), onSystem: resolvedItem.systemID) }
            )
        case .extraDiskIOQueueDepth(let name):
            ExtraDiskIOQueueDepthChartView(
                diskName: name,
                dataPoints: systemData,
                xAxisFormat: store.xAxisFormat,
                systemName: systemName,
                isPinned: store.isPinned(.extraDiskIOQueueDepth(name: name), onSystem: resolvedItem.systemID),
                onPinToggle: { store.togglePin(for: .extraDiskIOQueueDepth(name: name), onSystem: resolvedItem.systemID) }
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
                    subtitleKey: "chart.container.cpuUsage.subtitle",
                    systemName: systemName,
                    isPinned: store.isPinned(.containerCPU(name: container.name), onSystem: resolvedItem.systemID),
                    onPinToggle: { store.togglePin(for: .containerCPU(name: container.name), onSystem: resolvedItem.systemID) },
                    yAxisFormatter: { String(format: "%.0f", $0) },
                    yAxisUnit: "%"
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
                    subtitleKey: "chart.container.memoryUsage.subtitle",
                    systemName: systemName,
                    isPinned: store.isPinned(.containerMemory(name: container.name), onSystem: resolvedItem.systemID),
                    onPinToggle: { store.togglePin(for: .containerMemory(name: container.name), onSystem: resolvedItem.systemID) },
                    yAxisFormatter: { String(format: "%.0f", $0) },
                    yAxisUnit: "MB"
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
        case .smartDevice(let name):
            let devices = store.smartDevices(forSystemID: resolvedItem.systemID)
            if let device = devices.first(where: { $0.name == name }) {
                SmartDeviceCard(
                    device: device,
                    isPinned: store.isPinned(.smartDevice(name: name), onSystem: resolvedItem.systemID),
                    onPinToggle: { store.togglePin(for: .smartDevice(name: name), onSystem: resolvedItem.systemID) }
                )
            }
        }
    }
}
