import SwiftUI

struct ContainerView: View {
    @Environment(BeszelStore.self) var store

    @Environment(SettingsManager.self) var settingsManager
    @Environment(DashboardManager.self) var dashboardManager
    @Environment(InstanceManager.self) var instanceManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
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

                    if store.hasContainerNetworkData {
                        StackedNetworkChartView(
                            stackedData: store.stackedNetworkData,
                            domain: store.networkDomain,
                            systemID: instanceManager.activeSystem?.id
                        )
                    }
                }
                .environment(\.chartXDomain, store.xDomain)
                .environment(\.chartShowXGridLines, settingsManager.showChartGridLines)
                .padding(.horizontal)
                .opacity(store.containerData.isEmpty ? 0 : 1)

                containerList
                    .padding(.horizontal)
                    .opacity(hasContainers ? 1 : 0)
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("container.title")
        .monitoringNavigationSubtitle("container.subtitle")
        .navigationBarTitleDisplayMode(.large)
        .monitoringScreenBackground()
        .groupBoxStyle(CardGroupBoxStyle())
        .refreshable {
            await store.fetchData()
        }
        .overlay {
            if store.isLoading && !hasContainers {
                MonitoringStateView(state: .loading("switcher.loading"))
            } else if let errorMessage = store.errorMessage, !hasContainers {
                MonitoringStateView(state: .failure(errorMessage)) {
                    store.clearAuthenticationError()
                    Task {
                        await store.fetchData()
                    }
                }
            } else if !hasContainers {
                MonitoringStateView(
                    state: .empty(
                        title: "common.noData",
                        message: "widget.noData",
                        systemImage: "shippingbox"
                    )
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
            .padding(.vertical, MonitoringSpacing.compact)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: MonitoringRadius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: MonitoringRadius.card, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
            }
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
                    if let net = container.net, net > 0 {
                        Label(formatNetwork(net), systemImage: "network")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if let image = container.image {
                    Label(image, systemImage: "shippingbox")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                switch ContainerRowStatusPresentation(
                    health: container.health,
                    runtimeState: container.runtimeState
                ) {
                case .health(let health):
                    HealthBadge(health: health)
                case .runtime(let state):
                    ContainerRuntimeBadge(
                        status: container.status,
                        state: state
                    )
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
    
    private func formatCPU(_ value: Double) -> String {
        MetricFormatter.percent(value)
    }
    
    private func formatMemory(_ mb: Double) -> String {
        MetricFormatter.memory(megabytes: mb)
    }
    
    private func formatNetwork(_ bytesPerSecond: Double) -> String {
        MetricFormatter.throughput(bytesPerSecond: bytesPerSecond)
    }
}

nonisolated enum ContainerRowStatusPresentation: Equatable, Sendable {
    case health(ContainerHealth)
    case runtime(ContainerRuntimeState)

    init(health: ContainerHealth?, runtimeState: ContainerRuntimeState) {
        if let health, health != .none {
            self = .health(health)
        } else {
            self = .runtime(runtimeState)
        }
    }
}

private struct ContainerRuntimeBadge: View {
    let status: String
    let state: ContainerRuntimeState

    var body: some View {
        Group {
            switch state {
            case .running:
                Text("container.status.running")
            case .stopped:
                Label("container.status.stopped", systemImage: "stop.circle.fill")
            case .unknown:
                Label(status, systemImage: "questionmark.circle")
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(state == .running ? Color.green : Color.secondary)
    }
}

struct HealthBadge: View {
    let health: ContainerHealth

    var body: some View {
        if health != .none {
            Text(LocalizedStringKey(health.displayTextKey))
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .clipShape(Capsule())
                .accessibilityLabel(Text(LocalizedStringKey(health.displayTextKey)))
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
