import SwiftUI
import Charts

struct ContainerDetailView: View {
    let container: ProcessedContainerData
    
    @Environment(SettingsManager.self) var settingsManager
    @Environment(DashboardManager.self) var dashboardManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(container.name)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            VStack(alignment: .leading, spacing: 24) {
                ContainerCpuChartView(
                    xAxisFormat: settingsManager.selectedTimeRange.xAxisFormat,
                    container: container,
                    isPinned: dashboardManager.isPinned(.containerCPU(name: container.name)),
                    onPinToggle: { dashboardManager.togglePin(for: .containerCPU(name: container.name)) }
                )
                
                ContainerMemoryChartView(
                    xAxisFormat: settingsManager.selectedTimeRange.xAxisFormat,
                    container: container,
                    isPinned: dashboardManager.isPinned(.containerMemory(name: container.name)),
                    onPinToggle: { dashboardManager.togglePin(for: .containerMemory(name: container.name)) }
                )
                Spacer()
            }
            .padding()
        }
    }
}
