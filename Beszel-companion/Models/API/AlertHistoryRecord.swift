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
}
