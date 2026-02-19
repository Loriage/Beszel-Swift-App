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

    var displayNameKey: String {
        alertType.displayNameKey
    }

    var thresholdDescription: String {
        guard let val = value else { return "-" }
        if let min = min {
            return "\(alertType.formatValue(min)) - \(alertType.formatValue(val))"
        }
        return alertType.formatValue(val)
    }

    var activeDescriptionFormatted: String {
        alertType.formatValue(value ?? 0)
    }

    var activeDescriptionMinutes: Int? {
        guard let min = min, min > 0 else { return nil }
        return Int(min)
    }
}

enum AlertType: String, CaseIterable, Identifiable, Sendable {
    var id: String { rawValue }

    case status = "Status"
    case cpu = "CPU"
    case memory = "Memory"
    case disk = "Disk"
    case bandwidth = "Bandwidth"
    case gpu = "GPU"
    case temperature = "Temperature"
    case loadAverage1m = "LoadAvg1"
    case loadAverage5m = "LoadAvg5"
    case loadAverage15m = "LoadAvg15"
    case battery = "Battery"

    var displayNameKey: String {
        switch self {
        case .status: return "alerts.type.name.status"
        case .cpu: return "alerts.type.name.cpu"
        case .memory: return "alerts.type.name.memory"
        case .disk: return "alerts.type.name.disk"
        case .bandwidth: return "alerts.type.name.bandwidth"
        case .temperature: return "alerts.type.name.temperature"
        case .loadAverage1m: return "alerts.type.name.loadAverage1m"
        case .loadAverage5m: return "alerts.type.name.loadAverage5m"
        case .loadAverage15m: return "alerts.type.name.loadAverage15m"
        case .battery: return "alerts.type.name.battery"
        case .gpu: return "alerts.type.name.gpu"
        }
    }

    var displayName: String {
        String(localized: String.LocalizationValue(displayNameKey))
    }

    var alertDescriptionKey: String {
        switch self {
        case .status: return "alerts.type.description.status"
        case .cpu: return "alerts.type.description.cpu"
        case .memory: return "alerts.type.description.memory"
        case .disk: return "alerts.type.description.disk"
        case .bandwidth: return "alerts.type.description.bandwidth"
        case .temperature: return "alerts.type.description.temperature"
        case .loadAverage1m: return "alerts.type.description.loadAverage1m"
        case .loadAverage5m: return "alerts.type.description.loadAverage5m"
        case .loadAverage15m: return "alerts.type.description.loadAverage15m"
        case .battery: return "alerts.type.description.battery"
        case .gpu: return "alerts.type.description.gpu"
        }
    }

    var needsThreshold: Bool {
        self != .status
    }

    var iconName: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "externaldrive"
        case .bandwidth: return "network"
        case .temperature: return "thermometer.medium"
        case .loadAverage1m, .loadAverage5m, .loadAverage15m: return "hourglass"
        case .status: return "power"
        case .battery: return "battery.75percent"
        case .gpu: return "square.stack.3d.up"
        }
    }

    func formatValue(_ value: Double) -> String {
        switch self {
        case .cpu, .memory, .disk, .gpu, .battery:
            return String(format: "%.0f%%", value)
        case .bandwidth:
            return String(format: "%.0f MB/s", value)
        case .temperature:
            return String(format: "%.0f°C", value)
        case .loadAverage1m, .loadAverage5m, .loadAverage15m:
            return String(format: "%.0f", value)
        case .status:
            return value > 0 ? "Online" : "Offline"
        }
    }
}
