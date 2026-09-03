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
    var triggered: Bool? = nil
}

extension AlertRecord {
    var alertType: AlertType {
        AlertType.classify(name)
    }

    var displayName: String {
        alertType.displayName(for: name)
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
        guard alertType.supportsDuration, let min = min, min > 0 else { return nil }
        return Int(min)
    }
}

enum AlertType: String, CaseIterable, Identifiable, Sendable {
    var id: String { rawValue }

    case status = "Status"
    case cpu = "CPU"
    case cpuIOWait = "CPUIOWait"
    case cpuSteal = "CPUSteal"
    case containerHealth = "ContainerHealth"
    case systemdFailed = "SystemdFailed"
    case memory = "Memory"
    case disk = "Disk"
    case bandwidth = "Bandwidth"
    case gpu = "GPU"
    case temperature = "Temperature"
    case loadAverage1m = "LoadAvg1"
    case loadAverage5m = "LoadAvg5"
    case loadAverage15m = "LoadAvg15"
    case battery = "Battery"
    case zfsPool = "ZFS Pool"
    case other = "Other"

    static func classify(_ name: String) -> Self {
        if let type = Self(rawValue: name) { return type }
        return name.hasPrefix("ZFS Pool: ") ? .zfsPool : .other
    }

    func displayName(for name: String) -> String {
        switch self {
        case .zfsPool, .other: name
        default: displayName
        }
    }

    var isConfigurable: Bool { self != .zfsPool && self != .other }
    var requires019: Bool {
        [.cpuIOWait, .cpuSteal, .containerHealth, .systemdFailed].contains(self)
    }

    func isAvailable(hubInfo: HubInfo?, system: SystemRecord?, stats: SystemStatsDetail?) -> Bool {
        guard isConfigurable else { return false }
        guard requires019 else { return true }
        guard hubInfo?.supports019 == true else { return false }
        switch self {
        case .cpuIOWait, .cpuSteal: return (stats?.cpuBreakdown?.count ?? 0) >= 4
        case .systemdFailed: return system?.info?.sv != nil
        default: return true
        }
    }

    var displayNameKey: String {
        switch self {
        case .status: return "alerts.type.name.status"
        case .cpu: return "alerts.type.name.cpu"
        case .cpuIOWait: return "alerts.type.name.cpuIOWait"
        case .cpuSteal: return "alerts.type.name.cpuSteal"
        case .containerHealth: return "alerts.type.name.containerHealth"
        case .systemdFailed: return "alerts.type.name.systemdFailed"
        case .zfsPool: return "alerts.type.name.zfsPool"
        case .other: return "alerts.type.name.other"
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
        case .cpuIOWait: return "alerts.type.description.cpuIOWait"
        case .cpuSteal: return "alerts.type.description.cpuSteal"
        case .containerHealth: return "alerts.type.description.containerHealth"
        case .systemdFailed: return "alerts.type.description.systemdFailed"
        case .zfsPool: return "alerts.type.description.zfsPool"
        case .other: return "alerts.type.name.other"
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
        isConfigurable && ![.status, .containerHealth, .systemdFailed].contains(self)
    }

    var supportsDuration: Bool { isConfigurable && self != .systemdFailed }

    var iconName: String {
        switch self {
        case .cpu, .cpuIOWait, .cpuSteal: return "cpu"
        case .containerHealth: return "shippingbox"
        case .systemdFailed: return "gearshape.2"
        case .zfsPool: return "externaldrive.badge.exclamationmark"
        case .other: return "exclamationmark.triangle"
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
        case .cpu, .cpuIOWait, .cpuSteal, .memory, .disk, .gpu, .battery:
            return String(format: "%.0f%%", value)
        case .bandwidth:
            return String(format: "%.0f MB/s", value)
        case .temperature:
            return String(format: "%.0f°C", value)
        case .loadAverage1m, .loadAverage5m, .loadAverage15m:
            return String(format: "%.0f", value)
        case .status:
            return value > 0 ? "Online" : "Offline"
        case .containerHealth, .systemdFailed, .zfsPool:
            // These are state alerts, not numeric thresholds or status=0/1.
            return String(localized: String.LocalizationValue(alertDescriptionKey))
        case .other:
            return value.formatted()
        }
    }
}
