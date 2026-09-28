import Foundation

nonisolated struct NetworkMonitorRecord: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let system: String
    let target: String
    let `protocol`: String
    let port: Int
    let interval: Int
    let enabled: Bool
    let res: Double?
    let resAvg1h: Double?
    let resMin1h: Double?
    let resMax1h: Double?
    let loss1h: Double?
    let updated: String?

    var targetLabel: String {
        guard `protocol` == "tcp" else { return target }
        let host = target.contains(":") && !target.hasPrefix("[") ? "[\(target)]" : target
        return "\(host):\(port)"
    }

    var updatedDate: Date? {
        updated.flatMap { DateFormatter.pocketBase.date(from: $0) }
    }

    func isStale(at now: Date) -> Bool {
        guard let updatedDate else { return true }
        return now.timeIntervalSince(updatedDate) > Double(max(interval * 3, 120))
    }
}

nonisolated struct NetworkMonitorStatsRecord: Codable, Identifiable, Sendable {
    let id: String
    let system: String
    let monitor: String
    let created: Double
    let type: String
    let totalCount: Int64
    let successCount: Int64
    let responseSum: Double
    let responseMin: Double
    let responseMax: Double

    enum CodingKeys: String, CodingKey {
        case id, system, monitor, created, type
        case totalCount = "total_count", successCount = "success_count"
        case responseSum = "res_sum", responseMin = "res_min", responseMax = "res_max"
    }

    var date: Date { Date(timeIntervalSince1970: created / 1000) }
    var validCounts: Bool { totalCount > 0 && successCount >= 0 && successCount <= totalCount }
    var latency: Double? {
        guard validCounts, successCount > 0, responseSum.isFinite, responseSum >= 0 else { return nil }
        return responseSum / Double(successCount) / 1000
    }
    var loss: Double? {
        guard validCounts else { return nil }
        return Double(totalCount - successCount) / Double(totalCount) * 100
    }
}

nonisolated enum NetworkMonitorProtocol: String, CaseIterable, Identifiable, Sendable {
    case icmp, tcp, http, dns
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

nonisolated struct NetworkMonitorConfiguration: Sendable {
    let system: String
    let target: String
    let `protocol`: NetworkMonitorProtocol
    let port: Int
    let interval: Int
    let enabled: Bool

    init(system: String, target: String, protocol kind: NetworkMonitorProtocol, port: String, interval: String, enabled: Bool) throws {
        var target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty, target.count <= 500, !target.contains(where: { $0.isWhitespace }) else {
            throw ValidationError.target
        }
        if kind == .http {
            if !target.contains("://") { target = "https://" + target }
            guard let url = URLComponents(string: target), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  let host = url.host, !host.isEmpty else { throw ValidationError.target }
        } else if target.contains("://") || target.contains("/") {
            throw ValidationError.target
        }
        guard let interval = Int(interval), (1...3600).contains(interval) else { throw ValidationError.interval }
        let port = kind == .tcp ? Int(port) : 0
        guard let port, kind != .tcp || (1...65535).contains(port) else { throw ValidationError.port }
        self.system = system
        self.target = target
        self.protocol = kind
        self.port = port
        self.interval = interval
        self.enabled = enabled
    }

    enum ValidationError: LocalizedError {
        case target, port, interval
        var errorDescription: String? {
            switch self {
            case .target: String(localized: "monitor.validation.target")
            case .port: String(localized: "monitor.validation.port")
            case .interval: String(localized: "monitor.validation.interval")
            }
        }
    }
}
