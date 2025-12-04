import SwiftUI

struct ContainerView: View {
    let viewModel: ContainerViewModel
    
    @Environment(SettingsManager.self) var settingsManager
    @Environment(DashboardManager.self) var dashboardManager
    @Environment(InstanceManager.self) var instanceManager
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ScreenHeaderView(title: "container.title", subtitle: "container.subtitle")
                
                if !viewModel.processedData.isEmpty {
                    VStack(alignment: .leading, spacing: 24) {
                        StackedCpuChartView(
                            settingsManager: settingsManager,
                            processedData: viewModel.processedData,
                            systemID: instanceManager.activeSystem?.id
                        )
                        
                        StackedMemoryChartView(
                            settingsManager: settingsManager,
                            processedData: viewModel.processedData,
                            systemID: instanceManager.activeSystem?.id
                        )
                    }
                    .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(viewModel.sortedData.enumerated()), id: \.element.id) { index, container in
                            NavigationLink(destination: ContainerDetailView(
                                container: container,
                                settingsManager: settingsManager,
                                dashboardManager: dashboardManager
                            )) {
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
                            
                            if index < viewModel.sortedData.count - 1 {
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
            await viewModel.fetchData()
        }
    }
}
