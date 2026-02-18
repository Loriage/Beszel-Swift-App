import SwiftUI

struct AlertsTabView: View {
    @Environment(AlertManager.self) var alertManager
    @Environment(InstanceManager.self) var instanceManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeaderView(title: "alerts.title", subtitle: "alerts.subtitle")

                // Navigation rows
                VStack(spacing: 0) {
                    NavigationLink {
                        AlertHistoryView()
                            .environment(instanceManager)
                            .environment(alertManager)
                            .navigationTitle("alerts.history.title")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack(spacing: 16) {
                            Text("alerts.history.title")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal)
                    }

                    Divider()
                        .padding(.leading, 16)

                    NavigationLink {
                        ConfiguredAlertsView()
                            .environment(instanceManager)
                            .environment(alertManager)
                            .navigationTitle("alerts.configured.title")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack(spacing: 16) {
                            Text("alerts.configured.title")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)

                // Active Alerts
                activeAlertsSection
            }
            .padding(.bottom, 24)
        }
        .groupBoxStyle(CardGroupBoxStyle())
        .refreshable {
            await refreshAlerts()
        }
    }

    // MARK: - Active Alerts

    @ViewBuilder
    private var activeAlertsSection: some View {
        let activeAlerts = alertManager.alertHistory.filter { !$0.isResolved }

        if !activeAlerts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("alerts.active.title")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.horizontal)

                LazyVStack(spacing: 12) {
                    ForEach(activeAlerts) { alert in
                        let systemName = instanceManager.systems.first { $0.id == alert.system }?.name
                        let isMuted = alertManager.isAlertMuted(alert.id)
                        let configuredAlert = alertManager.configuredAlert(for: alert)
                        ActiveAlertCard(
                            alert: alert,
                            systemName: systemName,
                            configuredAlert: configuredAlert,
                            isMuted: isMuted
                        ) {
                            alertManager.toggleMute(for: alert.id)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func refreshAlerts() async {
        guard let instance = instanceManager.activeInstance else { return }
        await alertManager.fetchAlerts(for: instance, instanceManager: instanceManager)
    }
}
