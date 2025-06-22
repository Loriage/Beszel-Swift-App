import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var dashboardManager: DashboardManager
    @EnvironmentObject var settingsManager: SettingsManager

    let containerData: [ProcessedContainerData]
    let systemDataPoints: [SystemDataPoint]

    var onShowSettings: () -> Void

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
                    .padding(.horizontal)
                }
                .navigationTitle("Accueil")
                .navigationSubtitle("Vos graphiques épinglés")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: onShowSettings) {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }
            }
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

    @ViewBuilder
    private func pinnedItemView(for item: PinnedItem) -> some View {
        switch item {
        case .systemCPU:
            SystemCpuChartView(dataPoints: systemDataPoints)
        case .systemMemory:
            SystemMemoryChartView(dataPoints: systemDataPoints)
        case .systemTemperature:
            SystemTemperatureChartView(dataPoints: systemDataPoints)
        case .containerCPU(let name):
            if let container = containerData.first(where: { $0.id == name }) {
                ContainerCpuChartView(container: container)
            }
        case .containerMemory(let name):
            if let container = containerData.first(where: { $0.id == name }) {
                ContainerMemoryChartView(container: container)
            }
        }
    }
}
