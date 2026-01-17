import SwiftUI

struct AlertCard: View {
    let alert: AlertRecord
    let systemName: String?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: alert.alertType.iconName)
                        .foregroundColor(.accentColor)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.displayName)
                            .font(.headline)
                        if let name = systemName {
                            Text(name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Text(alert.thresholdDescription)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

struct AlertHistoryRow: View {
    let alert: AlertHistoryRecord
    let systemName: String?
    let isUnread: Bool

    private var statusColor: Color {
        alert.isResolved ? .green : .red
    }

    var body: some View {
        GroupBox {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: alert.alertType.iconName)
                        .foregroundColor(statusColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(alert.displayName)
                            .font(.headline)

                        if isUnread {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }
                    }

                    if let name = systemName {
                        Text(name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 6) {
                        Text(alert.timeAgoDescription)
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        // Status badge
                        Text(alert.isResolved ? String(localized: "alerts.status.resolved") : String(localized: "alerts.status.active"))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(statusColor)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(alert.triggeredValueDescription)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor)

                    // Status icon
                    Image(systemName: alert.isResolved ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(statusColor)
                }
            }
        }
    }
}
