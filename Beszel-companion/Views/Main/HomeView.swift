import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var dashboardManager: DashboardManager
    @EnvironmentObject var settingsManager: SettingsManager

    let containerData: [ProcessedContainerData]
    let systemDataPoints: [SystemDataPoint]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading) {
                    Text("home.title")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("home.subtitle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                if dashboardManager.pinnedItems.isEmpty {
                    emptyStateView
                } else {
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 24) {
                        ForEach(dashboardManager.pinnedItems) { item in
                            pinnedItemView(for: item)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack (alignment: .center, spacing: 8) {
            Image(systemName: "pin.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("home.empty.title")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 8)
            Text("home.empty.message")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.top, 80)
    }
    
    private var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }
    private var hasTemperatureData: Bool {
        systemDataPoints.contains { !$0.temperatures.isEmpty }
    }

    @ViewBuilder
    private func pinnedItemView(for item: PinnedItem) -> some View {
        switch item {
        case .systemCPU:
            SystemCpuChartView(
                xAxisFormat: xAxisFormat,
                dataPoints: systemDataPoints,
                isPinned: dashboardManager.isPinned(.systemCPU),
                onPinToggle: { dashboardManager.togglePin(for: .systemCPU) }
            )
        case .systemMemory:
            SystemMemoryChartView(
                xAxisFormat: xAxisFormat,
                dataPoints: systemDataPoints,
                isPinned: dashboardManager.isPinned(.systemMemory),
                onPinToggle: { dashboardManager.togglePin(for: .systemMemory) }
            )
        case .systemTemperature:
            if hasTemperatureData {
                SystemTemperatureChartView(
                    xAxisFormat: xAxisFormat,
                    dataPoints: systemDataPoints,
                    isPinned: dashboardManager.isPinned(.systemTemperature),
                    onPinToggle: { dashboardManager.togglePin(for: .systemTemperature) }
                )
            }
        case .containerCPU(let name):
            if let container = containerData.first(where: { $0.id == name }) {
                ContainerCpuChartView(
                    xAxisFormat: xAxisFormat,
                    container: container,
                    isPinned: dashboardManager.isPinned(.containerCPU(name: container.name)),
                    onPinToggle: { dashboardManager.togglePin(for: .containerCPU(name: container.name)) }
                )
            }
        case .containerMemory(let name):
            if let container = containerData.first(where: { $0.id == name }) {
                ContainerMemoryChartView(
                    xAxisFormat: xAxisFormat,
                    container: container,
                    isPinned: dashboardManager.isPinned(.containerMemory(name: container.name)),
                    onPinToggle: { dashboardManager.togglePin(for: .containerMemory(name: container.name)) }
                )
            }
        }
    }
}
