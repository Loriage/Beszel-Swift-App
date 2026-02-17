import SwiftUI

struct AlertHistoryView: View {
    @Environment(AlertManager.self) var alertManager
    @Environment(InstanceManager.self) var instanceManager

    @State private var selectedSystemID: String?

    var body: some View {
        VStack(spacing: 0) {
            systemFilterView

            contentView
        }
        .onAppear {
            alertManager.markAllAsRead()
            if alertManager.alertHistory.isEmpty {
                Task {
                    await refreshAlerts()
                }
            }
        }
    }

    @ViewBuilder
    private var systemFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: String(localized: "alerts.filter.all"),
                    isSelected: selectedSystemID == nil
                ) {
                    selectedSystemID = nil
                }

                ForEach(instanceManager.systems, id: \.id) { system in
                    FilterChip(
                        title: system.name,
                        isSelected: selectedSystemID == system.id
                    ) {
                        selectedSystemID = system.id
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        let filteredHistory = filterHistory()

        if filteredHistory.isEmpty {
            ContentUnavailableView {
                Label("alerts.history.empty.title", systemImage: "bell.slash")
            } description: {
                Text("alerts.history.empty.message")
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredHistory) { alert in
                        let systemName = instanceManager.systems.first { $0.id == alert.system }?.name
                        NavigationLink {
                            AlertDetailView(alert: AlertDetail(alert: alert, systemName: systemName))
                        } label: {
                            AlertHistoryRow(
                                alert: alert,
                                systemName: systemName,
                                isUnread: false
                            )
                        }
                    }
                }
                .padding()
            }
            .groupBoxStyle(CardGroupBoxStyle())
            .refreshable {
                await refreshAlerts()
            }
        }
    }

    private func filterHistory() -> [AlertHistoryRecord] {
        guard let systemID = selectedSystemID else {
            return alertManager.alertHistory
        }
        return alertManager.historyForSystem(systemID)
    }

    private func refreshAlerts() async {
        guard let instance = instanceManager.activeInstance else { return }
        await alertManager.fetchAlerts(for: instance, instanceManager: instanceManager)
    }
}

struct ConfiguredAlertsView: View {
    @Environment(AlertManager.self) var alertManager
    @Environment(InstanceManager.self) var instanceManager

    @State private var selectedSystemID: String?

    var body: some View {
        VStack(spacing: 0) {
            systemFilterView

            contentView
        }
    }

    @ViewBuilder
    private var systemFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: String(localized: "alerts.filter.all"),
                    isSelected: selectedSystemID == nil
                ) {
                    selectedSystemID = nil
                }

                ForEach(instanceManager.systems, id: \.id) { system in
                    FilterChip(
                        title: system.name,
                        isSelected: selectedSystemID == system.id
                    ) {
                        selectedSystemID = system.id
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        let filteredAlerts = filterAlerts()

        if filteredAlerts.isEmpty {
            ContentUnavailableView {
                Label("alerts.configured.empty.title", systemImage: "bell.badge")
            } description: {
                Text("alerts.configured.empty.message")
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredAlerts) { alert in
                        let systemName = instanceManager.systems.first { $0.id == alert.system }?.name
                        AlertCard(alert: alert, systemName: systemName)
                    }
                }
                .padding()
            }
            .groupBoxStyle(CardGroupBoxStyle())
        }
    }

    private func filterAlerts() -> [AlertRecord] {
        guard let systemID = selectedSystemID else {
            return alertManager.alerts.values.flatMap { $0 }
        }
        return alertManager.alertsForSystem(systemID)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
