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
            LazyVStack(alignment: .leading, spacing: 10) {
                ScreenHeaderView(title: "container.title", subtitle: "container.subtitle")

                if !store.containerData.isEmpty {
                    VStack(alignment: .leading, spacing: 24) {
                        StackedCpuChartView(
                            settingsManager: settingsManager,
                            processedData: store.containerData,
                            systemID: instanceManager.activeSystem?.id
                        )
                        StackedMemoryChartView(
                            settingsManager: settingsManager,
                            processedData: store.containerData,
                            systemID: instanceManager.activeSystem?.id
                        )
                    }
                    .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(sortedData.enumerated()), id: \.element.id) { index, container in
                            NavigationLink(destination: ContainerDetailView(container: container)) {
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
                .padding()
            }
        }
        .refreshable {
            await store.fetchData()
        }
    }
}
