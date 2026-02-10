import SwiftUI

struct AlertDetailView: View {
    let alert: AlertDetail

    @Environment(InstanceManager.self) private var instanceManager

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var statusText: String {
        alert.isResolved
            ? String(localized: "alerts.status.resolved")
            : String(localized: "alerts.status.active")
    }

    private var statusColor: Color {
        alert.isResolved ? .green : .red
    }

    private var resolvedSystemName: String {
        if let systemName = alert.systemName {
            return systemName
        }
        return instanceManager.systems.first { $0.id == alert.systemId }?.name
            ?? String(localized: "Unknown")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GroupBox {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(statusColor.opacity(0.15))
                                .frame(width: 48, height: 48)

                            Image(systemName: alert.alertType.iconName)
                                .foregroundColor(statusColor)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(alert.displayName)
                                .font(.headline)

                            Text(resolvedSystemName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(alert.triggeredValueDescription)
                            .font(.headline)
                            .foregroundColor(statusColor)
                    }
                }

                GroupBox {
                    VStack(spacing: 12) {
                        detailRow(label: "system.title", value: resolvedSystemName)
                        detailRow(label: "Value", value: alert.triggeredValueDescription)
                        detailRow(label: "alerts.detail.status", value: statusText, valueColor: statusColor)
                        detailRow(label: "alerts.detail.triggeredAt", value: Self.dateFormatter.string(from: alert.created))

                        if let resolved = alert.resolved, !resolved.isEmpty {
                            detailRow(label: "alerts.detail.resolvedAt", value: resolved)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("alerts.detail.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func detailRow(label: LocalizedStringKey, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }
}
