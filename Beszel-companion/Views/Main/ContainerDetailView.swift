import SwiftUI
import Charts

struct ContainerDetailView: View {
    let container: ProcessedContainerData
    @ObservedObject var settingsManager: SettingsManager
    @EnvironmentObject var dashboardManager: DashboardManager

    private var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ContainerCpuChartView(
                    xAxisFormat: xAxisFormat,
                    container: container,
                    isPinned: dashboardManager.isPinned(.containerCPU(name: container.name)),
                    onPinToggle: { dashboardManager.togglePin(for: .containerCPU(name: container.name)) }
                )
                ContainerMemoryChartView(
                    xAxisFormat: xAxisFormat,
                    container: container,
                    isPinned: dashboardManager.isPinned(.containerMemory(name: container.name)),
                    onPinToggle: { dashboardManager.togglePin(for: .containerMemory(name: container.name)) }
                )

                Spacer()
            }
            .padding()
        }
        .navigationTitle(container.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
