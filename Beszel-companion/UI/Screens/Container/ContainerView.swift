import SwiftUI

struct ContainerView: View {
    @Environment(BeszelStore.self) var store

    @Environment(SettingsManager.self) var settingsManager
    @Environment(DashboardManager.self) var dashboardManager
    @Environment(InstanceManager.self) var instanceManager

    var sortedData: [ProcessedContainerData] {
        store.containerData.sorted(by: { $0.name < $1.name })
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ScreenHeaderView(
                    title: "container.title",
                    subtitle: store.isLoading ? "switcher.loading" : "container.subtitle"
                )

                if !store.containerData.isEmpty {
                    VStack(alignment: .leading, spacing: 24) {
                        StackedCpuChartView(
                            stackedData: store.stackedCpuData,
                            domain: store.cpuDomain,
                            systemID: instanceManager.activeSystem?.id
                        )
                        
                        StackedMemoryChartView(
                            stackedData: store.stackedMemoryData,
                            domain: store.memoryDomain,
                            systemID: instanceManager.activeSystem?.id
                        )
                    }
                    .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(store.sortedContainerData.enumerated()), id: \.element.id) { index, container in
                            NavigationLink(value: container) {
                                HStack {
                                    Text(container.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                            }
                            
                            if index < sortedData.count - 1 {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .background(Color(.systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(.horizontal)
            }
        }
        .navigationDestination(for: ProcessedContainerData.self) { container in
            ContainerDetailView(container: container)
        }
        .refreshable {
            await store.fetchData()
        }
    }
}
