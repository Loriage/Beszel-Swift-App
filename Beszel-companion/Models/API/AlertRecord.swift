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

    var displayName: String {
        switch self {
        case .status: return "Status"
        case .cpu: return "CPU Usage"
        case .memory: return "Memory Usage"
        case .disk: return "Disk Usage"
        case .bandwidth: return "Bandwidth"
        case .temperature: return "Temperature"
        case .loadAverage1m: return "Load Average 1m"
        case .loadAverage5m: return "Load Average 5m"
        case .loadAverage15m: return "Load Average 15m"
        case .battery: return "Battery"
        case .gpu: return "GPU Usage"
        }
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
