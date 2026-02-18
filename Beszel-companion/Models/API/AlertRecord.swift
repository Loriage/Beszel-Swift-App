import Foundation

nonisolated struct AlertRecord: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let value: Double?
    let min: Double?
    let system: String
    let user: String?
    let created: String?  // Keep as String to avoid date parsing issues
    let updated: String?
}

extension AlertRecord {
    var alertType: AlertType {
        AlertType(rawValue: name) ?? .status
    }

    var displayName: String {
        alertType.displayName
    }

    var thresholdDescription: String {
        guard let val = value else { return "-" }
        if let min = min {
            return "\(alertType.formatValue(min)) - \(alertType.formatValue(val))"
        }
        return alertType.formatValue(val)
    }

    var activeDescription: String {
        guard let val = value else { return "-" }
        let formatted = alertType.formatValue(val)
        guard let min = min, min > 0 else {
            return "Exceeds \(formatted)"
        }
        let minutes = Int(min)
        return "Exceeds \(formatted) in last \(minutes) minute\(minutes == 1 ? "" : "s")"
    }
}

enum AlertType: String, Sendable {
    case cpu = "CPU"
    case memory = "Memory"
    case disk = "Disk"
    case bandwidth = "Bandwidth"
    case temperature = "Temperature"
    case loadAverage = "Load Average"
    case status = "Status"

    var displayName: String {
        rawValue
    }

    var iconName: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "externaldrive"
        case .bandwidth: return "network"
        case .temperature: return "thermometer.medium"
        case .loadAverage: return "chart.bar"
        case .status: return "power"
        }
    }

    func formatValue(_ value: Double) -> String {
        switch self {
        case .cpu, .memory, .disk:
            return String(format: "%.0f%%", value)
        case .bandwidth:
            return String(format: "%.1f MB/s", value)
        case .temperature:
            return String(format: "%.0f°C", value)
        case .loadAverage:
            return String(format: "%.2f", value)
        case .status:
            return value > 0 ? "Online" : "Offline"
        }
    }
}
