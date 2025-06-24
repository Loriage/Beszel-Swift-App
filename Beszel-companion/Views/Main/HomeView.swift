import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var dashboardManager: DashboardManager
    @EnvironmentObject var settingsManager: SettingsManager

    let containerData: [ProcessedContainerData]
    let systemDataPoints: [SystemDataPoint]

    @Binding var isShowingSettings: Bool

    var body: some View {
        NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if dashboardManager.pinnedItems.isEmpty {
                            emptyStateView
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible())], spacing: 24) {
                                ForEach(dashboardManager.pinnedItems) { item in
                                    pinnedItemView(for: item)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Accueil")
                .navigationSubtitle("Vos graphiques épinglés")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {isShowingSettings = true}) {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }

            }
            .padding(.horizontal)
        }

    private var emptyStateView: some View {
        VStack (alignment: .center) {
            Spacer(minLength: 80)
            Image(systemName: "pin.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Votre accueil est vide")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 8)
            Text("Épinglez vos graphiques préférés depuis les pages Système et Conteneurs pour les voir ici.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }
    
    private var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
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
            SystemTemperatureChartView(
                xAxisFormat: xAxisFormat,
                dataPoints: systemDataPoints,
                isPinned: dashboardManager.isPinned(.systemTemperature),
                onPinToggle: { dashboardManager.togglePin(for: .systemTemperature) }
            )
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
