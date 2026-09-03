import SwiftUI

struct AlertsTabView: View {
    @Environment(AlertManager.self) var alertManager
    @Environment(InstanceManager.self) var instanceManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)
                            Text("alerts.history.title")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
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
                            Image(systemName: "bell.badge")
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)
                            Text("alerts.configured.title")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 4)
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: MonitoringRadius.card, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: MonitoringRadius.card, style: .continuous)
                        .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
                }
                .padding(.horizontal)

                // Active Alerts
                activeAlertsSection
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("alerts.title")
        .monitoringNavigationSubtitle("alerts.subtitle")
        .navigationBarTitleDisplayMode(.large)
        .monitoringScreenBackground()
        .groupBoxStyle(CardGroupBoxStyle())
        .refreshable {
            await refreshAlerts()
        }
    }

    @ViewBuilder
    private var activeAlertsSection: some View {
        let activeAlerts = alertManager.alertHistory.filter { !$0.isResolved }

        VStack(alignment: .leading, spacing: 12) {
            Text("alerts.active.title")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)

            if activeAlerts.isEmpty {
                GroupBox {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 40, height: 40)

                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.green)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("alerts.active.empty")
                                .font(.headline)

                            Text("alerts.active.empty.description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }
                .padding(.horizontal)
            } else {
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
