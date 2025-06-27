import SwiftUI
import Charts

struct SystemView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var dashboardManager: DashboardManager

    @Binding var dataPoints: [SystemDataPoint]
    var fetchData: () async -> Void
    @Binding var isShowingSettings: Bool

    private var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }
    private var hasTemperatureData: Bool {
        dataPoints.contains { !$0.temperatures.isEmpty }
    }

    var body: some View {
        NavigationView {
            if dataPoints.isEmpty {
                ProgressView("system.loading")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SystemCpuChartView(
                            xAxisFormat: xAxisFormat,
                            dataPoints: dataPoints,
                            isPinned: dashboardManager.isPinned(.systemCPU),
                            onPinToggle: { dashboardManager.togglePin(for: .systemCPU) }
                        )
                        SystemMemoryChartView(
                            xAxisFormat: xAxisFormat,
                            dataPoints: dataPoints,
                            isPinned: dashboardManager.isPinned(.systemMemory),
                            onPinToggle: { dashboardManager.togglePin(for: .systemMemory) }
                        )
                        if hasTemperatureData {
                            SystemTemperatureChartView(
                                xAxisFormat: xAxisFormat,
                                dataPoints: dataPoints,
                                isPinned: dashboardManager.isPinned(.systemTemperature),
                                onPinToggle: { dashboardManager.togglePin(for: .systemTemperature) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .navigationTitle("system.title")
                .navigationSubtitle("system.subtitle")
                .refreshable {
                    await fetchData()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {isShowingSettings = true}) {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }
            }
        }
    }
}
