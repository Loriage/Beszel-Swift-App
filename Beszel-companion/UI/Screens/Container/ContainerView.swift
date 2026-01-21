import SwiftUI

struct ContainerView: View {
    @Environment(BeszelStore.self) var store

    @Environment(SettingsManager.self) var settingsManager
    @Environment(DashboardManager.self) var dashboardManager
    @Environment(InstanceManager.self) var instanceManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeaderView(
                    title: "container.title",
                    subtitle: store.isLoading ? "switcher.loading" : "container.subtitle"
                )

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
                .opacity(store.containerData.isEmpty ? 0 : 1)

                containerList
                    .padding(.horizontal)
                    .opacity(hasContainers ? 1 : 0)
            }
            .padding(.bottom, 24)
        }
        .refreshable {
            await store.fetchData()
        }
        .overlay {
            if store.isLoading && !hasContainers {
                ProgressView()
            } else if let errorMessage = store.errorMessage, !hasContainers {
                ContentUnavailableView {
                    Label("common.error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("common.retry") {
                        store.clearAuthenticationError()
                        Task {
                            await store.fetchData()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } else if !hasContainers {
                ContentUnavailableView(
                    "common.noData",
                    systemImage: "chart.bar.xaxis",
                    description: Text("widget.noData")
                )
            }
        }
    }

    private var hasContainers: Bool {
        !store.containerRecords.isEmpty || !store.containerData.isEmpty
    }

    @ViewBuilder
    private var containerList: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                let containers = store.sortedContainerRecords
                ForEach(Array(containers.enumerated()), id: \.element.id) { index, container in
                    let processedData = store.sortedContainerData.first { $0.name == container.name }

                    NavigationLink(value: processedData) {
                        ContainerRowView(container: container)
                    }
                    .disabled(processedData == nil)

                    if index < containers.count - 1 {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct ContainerRowView: View {
    let container: ContainerRecord
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(container.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label(formatCPU(container.cpu), systemImage: "cpu")
                    Label(formatMemory(container.memory), systemImage: "memorychip")
                    if container.net > 0 {
                        Label(formatNetwork(container.net), systemImage: "network")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Label(container.image, systemImage: "shippingbox")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HealthBadge(health: container.health)
                
                Text(container.status)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
    }
    
    private func formatCPU(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
    
    private func formatMemory(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
    
    /// Network value from API is in MB/s
    private func formatNetwork(_ mbs: Double) -> String {
        if mbs >= 1 {
            return String(format: "%.1f MB/s", mbs)
        }
        
        let kbs = mbs * 1024
        return String(format: "%.1f KB/s", kbs)
    }
}

struct HealthBadge: View {
    let health: ContainerHealth

    var body: some View {
        if health != .none {
            Text(health.displayText)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .clipShape(Capsule())
        }
    }

    private var backgroundColor: Color {
        switch health {
        case .none:
            return .clear
        case .starting:
            return .orange.opacity(0.15)
        case .healthy:
            return .green.opacity(0.15)
        case .unhealthy:
            return .red.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch health {
        case .none:
            return .secondary
        case .starting:
            return .orange
        case .healthy:
            return .green
        case .unhealthy:
            return .red
        }
    }
}
