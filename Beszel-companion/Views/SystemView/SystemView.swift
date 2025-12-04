import SwiftUI
import Charts

struct SystemView: View {
    @Environment(ChartDataManager.self) var chartData
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeaderView(title: "system.title", subtitle: "system.subtitle")
                
                VStack(alignment: .leading, spacing: 24) {
                    SystemCpuChartView(
                        xAxisFormat: chartData.xAxisFormat,
                        dataPoints: chartData.systemDataPoints,
                        isPinned: chartData.isPinned(.systemCPU),
                        onPinToggle: { chartData.togglePin(for: .systemCPU) }
                    )
                    SystemMemoryChartView(
                        xAxisFormat: chartData.xAxisFormat,
                        dataPoints: chartData.systemDataPoints,
                        isPinned: chartData.isPinned(.systemMemory),
                        onPinToggle: { chartData.togglePin(for: .systemMemory) }
                    )
                    if chartData.hasTemperatureData {
                        SystemTemperatureChartView(
                            xAxisFormat: chartData.xAxisFormat,
                            dataPoints: chartData.systemDataPoints,
                            isPinned: chartData.isPinned(.systemTemperature),
                            onPinToggle: { chartData.togglePin(for: .systemTemperature) }
                        )
                    }
                }
                .padding(.horizontal)
                .opacity(chartData.systemDataPoints.isEmpty ? 0 : 1)
            }
        }
        .refreshable {
            await chartData.fetchData()
        }
        .overlay {
            if chartData.isLoading && chartData.systemDataPoints.isEmpty {
                ProgressView()
            } else if let errorMessage = chartData.errorMessage, chartData.systemDataPoints.isEmpty {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
            } else if chartData.systemDataPoints.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.bar.xaxis",
                    description: Text("widget.noData")
                )
            }
        }
    }
}
