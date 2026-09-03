import SwiftUI
import Charts

struct SystemView: View {
    @Environment(BeszelStore.self) var store
    @Environment(InstanceManager.self) var instanceManager
    @Environment(SettingsManager.self) var settingsManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let latestStats = store.latestSystemStats, let system = instanceManager.activeSystem {
                    SystemSummaryCard(
                        system: system,
                        systemInfo: system.info,
                        stats: latestStats.stats,
                        systemName: system.name,
                        status: system.status,
                        isPinned: store.isPinned(.systemInfo),
                        onPinToggle: { store.togglePin(for: .systemInfo) }
                    )
                    .padding(.horizontal)
                    .transition(.scale.combined(with: .opacity))
                }

                if store.hasSmartData, let systemID = instanceManager.activeSystem?.id {
                    SmartHealthSummaryCard(devices: store.smartDevices, systemID: systemID)
                        .padding(.horizontal)
                }

                if !store.zfsPoolNames.isEmpty {
                    ZFSPoolsCard(
                        names: store.zfsPoolNames,
                        stats: store.latestSystemStats?.stats.zfsPools ?? [:],
                        records: store.zfsPools,
                        dataPoints: store.systemDataPoints,
                        xAxisFormat: store.xAxisFormat,
                        detailsUnavailable: store.zfsDetailsUnavailable
                    )
                    .environment(\.chartXDomain, store.xDomain)
                    .environment(\.chartShowXGridLines, settingsManager.showChartGridLines)
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 16) {
                    SystemCpuSummaryChartView(
                        dataPoints: store.systemDataPoints,
                        systemID: instanceManager.activeSystem?.id
                    )
                    SystemMetricChartView(
                        title: "chart.memoryUsage",
                        xAxisFormat: store.xAxisFormat,
                        dataPoints: store.systemDataPoints,
                        valueKeyPath: \.memoryPercent,
                        color: .green,
                        subtitle: "chart.memoryUsage.subtitle",
                        unit: "%",
                        isPinned: store.isPinned(.systemMemory),
                        onPinToggle: { store.togglePin(for: .systemMemory) }
                    )
                    DiskIOSummaryChartView(
                        dataPoints: store.systemDataPoints,
                        systemID: instanceManager.activeSystem?.id,
                        diskName: instanceManager.activeSystem?.info?.rdn
                    )
                    if store.hasDiskUsageData {
                        SystemDiskUsageChartView(
                            dataPoints: store.systemDataPoints,
                            xAxisFormat: store.xAxisFormat,
                            diskName: instanceManager.activeSystem?.info?.rdn,
                            isPinned: store.isPinned(.systemDiskUsage),
                            onPinToggle: { store.togglePin(for: .systemDiskUsage) }
                        )
                    }
                    BandwidthSummaryChartView(
                        dataPoints: store.systemDataPoints,
                        systemID: instanceManager.activeSystem?.id
                    )
                    SystemLoadChartView(
                        dataPoints: store.systemDataPoints,
                        xAxisFormat: store.xAxisFormat,
                        isPinned: store.isPinned(.systemLoadAverage),
                        onPinToggle: { store.togglePin(for: .systemLoadAverage) }
                    )
                    if store.hasTemperatureData {
                        SystemTemperatureChartView(
                            xAxisFormat: store.xAxisFormat,
                            dataPoints: store.systemDataPoints,
                            isPinned: store.isPinned(.systemTemperature),
                            onPinToggle: { store.togglePin(for: .systemTemperature) }
                        )
                    }
                    if store.hasSwapData {
                        SystemSwapChartView(
                            dataPoints: store.systemDataPoints,
                            xAxisFormat: store.xAxisFormat,
                            isPinned: store.isPinned(.systemSwap),
                            onPinToggle: { store.togglePin(for: .systemSwap) }
                        )
                    }
                    if store.hasGPUData {
                        SystemGPUChartView(
                            dataPoints: store.systemDataPoints,
                            xAxisFormat: store.xAxisFormat,
                            isPinned: store.isPinned(.systemGPU),
                            onPinToggle: { store.togglePin(for: .systemGPU) }
                        )
                    }
                    if store.hasExtraFilesystemsData {
                        ForEach(store.extraDiskNames, id: \.self) { diskName in
                            ExtraDiskUsageChartView(
                                diskName: diskName,
                                dataPoints: store.systemDataPoints,
                                xAxisFormat: store.xAxisFormat,
                                isPinned: store.isPinned(.extraDiskUsage(name: diskName)),
                                onPinToggle: { store.togglePin(for: .extraDiskUsage(name: diskName)) }
                            )
                            if store.hasIOData(forDisk: diskName) {
                                ExtraDiskIOSummaryChartView(
                                    diskName: diskName,
                                    dataPoints: store.systemDataPoints,
                                    systemID: instanceManager.activeSystem?.id
                                )
                            }
                        }
                    }
                }
                .environment(\.chartXDomain, store.xDomain)
                .environment(\.chartShowXGridLines, settingsManager.showChartGridLines)
                .padding(.horizontal)
                .opacity(store.systemDataPoints.isEmpty ? 0 : 1)
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("system.title")
        .monitoringNavigationSubtitle("system.subtitle")
        .navigationBarTitleDisplayMode(.large)
        .monitoringScreenBackground()
        .groupBoxStyle(CardGroupBoxStyle())
        .refreshable {
            await store.fetchData()
        }
        .overlay {
            if store.isLoading && store.systemDataPoints.isEmpty {
                MonitoringStateView(state: .loading("switcher.loading"))
            } else if let errorMessage = store.errorMessage, store.systemDataPoints.isEmpty {
                MonitoringStateView(state: .failure(errorMessage)) {
                    store.clearAuthenticationError()
                    Task {
                        await store.fetchData()
                    }
                }
            } else if store.systemDataPoints.isEmpty {
                MonitoringStateView(
                    state: .empty(
                        title: "common.noData",
                        message: "widget.noData",
                        systemImage: "chart.bar.xaxis"
                    )
                )
            }
        }
    }
}
