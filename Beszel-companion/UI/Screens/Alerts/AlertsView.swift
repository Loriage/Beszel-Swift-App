import SwiftUI

struct AlertHistoryView: View {
    @Environment(AlertManager.self) var alertManager
    @Environment(InstanceManager.self) var instanceManager

    @State private var searchText = ""
    @State private var isShowingFilterSheet = false
    @State private var selectedSystemID: String?
    @State private var selectedAlertType: AlertType?
    @State private var selectedState: AlertStateFilter = .all

    private var hasActiveFilters: Bool {
        selectedSystemID != nil || selectedAlertType != nil || selectedState != .all
    }

    private var filteredHistory: [AlertHistoryRecord] {
        var result: [AlertHistoryRecord]
        if let systemID = selectedSystemID {
            result = alertManager.historyForSystem(systemID)
        } else {
            result = alertManager.alertHistory
        }

        if let alertType = selectedAlertType {
            result = result.filter { $0.alertType == alertType }
        }

        switch selectedState {
        case .all: break
        case .active: result = result.filter { !$0.isResolved }
        case .resolved: result = result.filter { $0.isResolved }
        }

        guard !searchText.isEmpty else { return result }

        return result.filter { alert in
            let systemName = instanceManager.systems.first { $0.id == alert.system }?.name ?? ""
            return systemName.localizedCaseInsensitiveContains(searchText) ||
                alert.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBarView

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
        .sheet(isPresented: $isShowingFilterSheet) {
            AlertHistoryFilterView(
                selectedSystemID: $selectedSystemID,
                selectedAlertType: $selectedAlertType,
                selectedState: $selectedState
            )
        }
    }

    @ViewBuilder
    private var searchBarView: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search alerts", text: $searchText)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6), in: Capsule())

            Button {
                isShowingFilterSheet = true
            } label: {
                Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.title)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var contentView: some View {
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
                        AlertHistoryRow(
                            alert: alert,
                            systemName: systemName
                        )
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
