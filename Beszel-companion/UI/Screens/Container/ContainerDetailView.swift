import SwiftUI
import Charts

struct ContainerDetailView: View {
    let container: ProcessedContainerData
    
    @Environment(SettingsManager.self) var settingsManager
    @Environment(DashboardManager.self) var dashboardManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ContainerMetricChartView(
                    titleKey: "chart.container.cpuUsage.percent",
                    containerName: container.name,
                    xAxisFormat: settingsManager.selectedTimeRange.xAxisFormat,
                    container: container,
                    valueKeyPath: \.cpu,
                    color: .blue,
                    isPinned: dashboardManager.isPinned(.containerCPU(name: container.name)),
                    onPinToggle: { dashboardManager.togglePin(for: .containerCPU(name: container.name)) }
                )

                ContainerMetricChartView(
                    titleKey: "chart.container.memoryUsage.bytes",
                    containerName: container.name,
                    xAxisFormat: settingsManager.selectedTimeRange.xAxisFormat,
                    container: container,
                    valueKeyPath: \.memory,
                    color: .green,
                    isPinned: dashboardManager.isPinned(.containerMemory(name: container.name)),
                    onPinToggle: { dashboardManager.togglePin(for: .containerMemory(name: container.name)) }
                )
                Spacer()
            }
            .padding()
        }
        .navigationTitle(container.name)
    }
}
