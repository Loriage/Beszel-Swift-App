import SwiftUI
import Charts

struct SystemView: View {
    let systemViewModel: SystemViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeaderView(title: "system.title", subtitle: "system.subtitle")

                VStack(alignment: .leading, spacing: 24) {
                    SystemCpuChartView(
                        xAxisFormat: systemViewModel.chartDataManager.xAxisFormat,
                        dataPoints: systemViewModel.chartDataManager.systemDataPoints,
                        isPinned: systemViewModel.chartDataManager.isPinned(.systemCPU),
                        onPinToggle: { systemViewModel.chartDataManager.togglePin(for: .systemCPU) }
                    )
                    SystemMemoryChartView(
                        xAxisFormat: systemViewModel.chartDataManager.xAxisFormat,
                        dataPoints: systemViewModel.chartDataManager.systemDataPoints,
                        isPinned: systemViewModel.chartDataManager.isPinned(.systemMemory),
                        onPinToggle: { systemViewModel.chartDataManager.togglePin(for: .systemMemory) }
                    )
                    if systemViewModel.chartDataManager.hasTemperatureData {
                        SystemTemperatureChartView(
                            xAxisFormat: systemViewModel.chartDataManager.xAxisFormat,
                            dataPoints: systemViewModel.chartDataManager.systemDataPoints,
                            isPinned: systemViewModel.chartDataManager.isPinned(.systemTemperature),
                            onPinToggle: { systemViewModel.chartDataManager.togglePin(for: .systemTemperature) }
                        )
                    }
                }
                .padding(.horizontal)
                .opacity(systemViewModel.chartDataManager.systemDataPoints.isEmpty ? 0 : 1)
            }
        }
        .refreshable {
            // Task implicite
            systemViewModel.chartDataManager.fetchData()
        }
        .overlay {
            if systemViewModel.chartDataManager.isLoading && systemViewModel.chartDataManager.systemDataPoints.isEmpty {
                ProgressView()
            } else if let errorMessage = systemViewModel.chartDataManager.errorMessage, systemViewModel.chartDataManager.systemDataPoints.isEmpty {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Retry") {
                        systemViewModel.chartDataManager.fetchData()
                    }
                }
            } else if systemViewModel.chartDataManager.systemDataPoints.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.bar.xaxis",
                    description: Text("widget.noData")
                )
            }
        }
    }
}
