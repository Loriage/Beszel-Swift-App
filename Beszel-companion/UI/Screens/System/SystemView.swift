import SwiftUI
import Charts

struct SystemView: View {
    @Environment(BeszelStore.self) var store
    @Environment(InstanceManager.self) var instanceManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeaderView(
                    title: "system.title",
                    subtitle: store.isLoading ? "switcher.loading" : "system.subtitle"
                )
                
                if let latestStats = store.latestSystemStats, let system = instanceManager.activeSystem {
                    SystemSummaryCard(
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
                
                VStack(alignment: .leading, spacing: 24) {
                    SystemMetricChartView(
                        title: "chart.cpuUsage",
                        xAxisFormat: store.xAxisFormat,
                        dataPoints: store.systemDataPoints,
                        valueKeyPath: \.cpu,
                        color: .blue,
                        isPinned: store.isPinned(.systemCPU),
                        onPinToggle: { store.togglePin(for: .systemCPU) }
                    )
                    SystemMetricChartView(
                        title: "chart.memoryUsage",
                        xAxisFormat: store.xAxisFormat,
                        dataPoints: store.systemDataPoints,
                        valueKeyPath: \.memoryPercent,
                        color: .green,
                        isPinned: store.isPinned(.systemMemory),
                        onPinToggle: { store.togglePin(for: .systemMemory) }
                    )
                    SystemDiskIOChartView(
                        dataPoints: store.systemDataPoints,
                        xAxisFormat: store.xAxisFormat,
                        isPinned: store.isPinned(.systemDiskIO),
                        onPinToggle: { store.togglePin(for: .systemDiskIO) }
                    )
                    SystemBandwidthChartView(
                        dataPoints: store.systemDataPoints,
                        xAxisFormat: store.xAxisFormat,
                        isPinned: store.isPinned(.systemBandwidth),
                        onPinToggle: { store.togglePin(for: .systemBandwidth) }
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
                    if store.hasNetworkInterfacesData {
                        SystemNetworkInterfacesChartView(
                            dataPoints: store.systemDataPoints,
                            xAxisFormat: store.xAxisFormat,
                            isPinned: store.isPinned(.systemNetworkInterfaces),
                            onPinToggle: { store.togglePin(for: .systemNetworkInterfaces) }
                        )
                    }
                    if store.hasExtraFilesystemsData {
                        SystemExtraFilesystemsChartView(
                            dataPoints: store.systemDataPoints,
                            xAxisFormat: store.xAxisFormat,
                            isPinned: store.isPinned(.systemExtraFilesystems),
                            onPinToggle: { store.togglePin(for: .systemExtraFilesystems) }
                        )
                    }
                }
                .padding(.horizontal)
                .opacity(store.systemDataPoints.isEmpty ? 0 : 1)
            }
            .padding(.bottom, 24)
        }
        .refreshable {
            await store.fetchData()
        }
        .overlay {
            if store.isLoading && store.systemDataPoints.isEmpty {
                ProgressView()
            } else if let errorMessage = store.errorMessage, store.systemDataPoints.isEmpty {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
            } else if store.systemDataPoints.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.bar.xaxis",
                    description: Text("widget.noData")
                )
            }
        }
    }
}
