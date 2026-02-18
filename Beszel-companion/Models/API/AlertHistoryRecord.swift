import Foundation

nonisolated struct AlertHistoryRecord: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let alertId: String?
    let system: String
    let name: String
    let value: Double?
    let resolved: String?  // Keep as String to avoid date parsing issues
    let created: Date

    enum CodingKeys: String, CodingKey {
        case id
        case alertId = "alert_id"
        case system
        case name
        case value
        case resolved
        case created
    }
}

extension AlertHistoryRecord {
    var alertType: AlertType {
        AlertType(rawValue: name) ?? .status
    }

    var displayName: String {
        alertType.displayName
    }

    var triggeredValueDescription: String {
        guard let val = value else { return "-" }
        return alertType.formatValue(val)
    }

    var timeAgoDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: created, relativeTo: Date())
    }

    var isResolved: Bool {
        resolved?.isEmpty == false
    }

    var resolvedDate: Date? {
        guard let resolved, !resolved.isEmpty else { return nil }
        return DateFormatter.pocketBase.date(from: resolved)
    }

    var createdDateDescription: String {
        Self.compactDateFormatter.string(from: created)
    }

    var resolvedDateDescription: String? {
        guard let date = resolvedDate else { return nil }
        return Self.compactDateFormatter.string(from: date)
    }

    private static let compactDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMMd jj:mm", options: 0, locale: .current)
        return formatter
    }()

    var durationDescription: String? {
        let end = resolvedDate ?? Date()
        let interval = end.timeIntervalSince(created)
        guard interval >= 0 else { return nil }

        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}
