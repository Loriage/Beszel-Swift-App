import SwiftUI
import Charts

struct SystemView: View {
    @StateObject var systemViewModel: SystemViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading) {
                    Text("system.title")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("system.subtitle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                if systemViewModel.chartDataManager.systemDataPoints.isEmpty {
                    VStack {
                        ProgressView("system.loading")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    ScrollView {
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
                    }
                    .refreshable {
                        systemViewModel.chartDataManager.fetchData()
                    }
                }
            }
        }
    }
}
