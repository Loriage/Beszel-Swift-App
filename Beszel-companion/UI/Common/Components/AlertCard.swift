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
                    alertTitle
                        .font(.headline)
                        .foregroundColor(.primary)

                    AlertActiveDescriptionView(alert: alert)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
    }

    @ViewBuilder
    private var alertTitle: some View {
        if let name = systemName {
            Text("\(name) ") + Text(LocalizedStringKey(alert.displayNameKey))
        } else {
            Text(LocalizedStringKey(alert.displayNameKey))
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
                    alertTitle
                        .font(.headline)

                    if let configuredAlert {
                        AlertActiveDescriptionView(alert: configuredAlert)
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

    @ViewBuilder
    private var alertTitle: some View {
        if let name = systemName {
            Text("\(name) ") + Text(LocalizedStringKey(alert.displayNameKey))
        } else {
            Text(LocalizedStringKey(alert.displayNameKey))
        }
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
                    alertTitle
                        .font(.headline)
                        .foregroundColor(.primary)

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

    @ViewBuilder
    private var alertTitle: some View {
        if let name = systemName {
            Text("\(name) ") + Text(LocalizedStringKey(alert.displayNameKey))
        } else {
            Text(LocalizedStringKey(alert.displayNameKey))
        }
    }
}

// MARK: - Shared active description view

struct AlertActiveDescriptionView: View {
    let alert: AlertRecord

    var body: some View {
        let formatted = alert.activeDescriptionFormatted
        if let minutes = alert.activeDescriptionMinutes {
            if minutes == 1 {
                Text("alerts.description.exceedsWithDuration.singular \(formatted)")
            } else {
                Text("alerts.description.exceedsWithDuration.plural \(formatted) \(minutes)")
            }
        } else {
            Text("alerts.description.exceeds \(formatted)")
        }
    }
}
