import SwiftUI
import Charts

struct SystemView: View {
    @Environment(BeszelStore.self) var store
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeaderView(
                    title: "system.title",
                    subtitle: store.isLoading ? "switcher.loading" : "system.subtitle"
                )
                
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
                    if store.hasTemperatureData {
                        SystemTemperatureChartView(
                            xAxisFormat: store.xAxisFormat,
                            dataPoints: store.systemDataPoints,
                            isPinned: store.isPinned(.systemTemperature),
                            onPinToggle: { store.togglePin(for: .systemTemperature) }
                        )
                    }
                }
                .padding(.horizontal)
                .opacity(store.systemDataPoints.isEmpty ? 0 : 1)
            }
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
