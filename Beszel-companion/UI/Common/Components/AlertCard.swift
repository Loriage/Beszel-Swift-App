import SwiftUI

struct AlertCard: View {
    let alert: AlertRecord
    let systemName: String?

    var body: some View {
        GroupBox {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: alert.alertType.iconName)
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let name = systemName {
                        Text("\(name) \(alert.displayName)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    } else {
                        Text(alert.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    Text(alert.activeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
    }
}

struct ActiveAlertCard: View {
    let alert: AlertHistoryRecord
    let systemName: String?
    let configuredAlert: AlertRecord?
    let isMuted: Bool
    let onToggleMute: () -> Void

    var body: some View {
        GroupBox {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: alert.alertType.iconName)
                        .foregroundColor(.red)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let name = systemName {
                        Text("\(name) \(alert.displayName)")
                            .font(.headline)
                    } else {
                        Text(alert.displayName)
                            .font(.headline)
                    }

                    if let description = configuredAlert?.activeDescription {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: onToggleMute) {
                    Text(isMuted ? "alerts.active.unmute" : "alerts.active.mute")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isMuted ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.15))
                        .foregroundColor(isMuted ? .accentColor : .secondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(isMuted ? 0.6 : 1.0)
    }
}

struct AlertHistoryRow: View {
    let alert: AlertHistoryRecord
    let systemName: String?

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

                VStack(alignment: .leading, spacing: 2) {
                    if let name = systemName {
                        Text("\(name) \(alert.displayName)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    } else {
                        Text(alert.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    HStack(spacing: 4) {
                        Text(alert.createdDateDescription)
                        if let resolvedDate = alert.resolvedDateDescription {
                            Text("→")
                            Text(resolvedDate)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Text("alerts.history.value \(alert.triggeredValueDescription)")

                        if let duration = alert.durationDescription {
                            Text("alerts.history.duration \(duration)")
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
    }
}
