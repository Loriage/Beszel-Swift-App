import Foundation

nonisolated enum NetworkMonitorMetric: String, Sendable {
    case latency, loss
    var title: LocalizedStringResource {
        switch self {
        case .latency: "monitor.latency"
        case .loss: "monitor.loss"
        }
    }
    var unit: String { self == .latency ? "ms" : "%" }
    func pinnedItem(id: String) -> PinnedItem {
        self == .latency ? .networkMonitorLatency(id: id) : .networkMonitorLoss(id: id)
    }
}

nonisolated struct NetworkMonitorChartData: Sendable {
    struct Sample: Identifiable, Sendable {
        let id: String
        let date: Date
        let average: Double?
        let minimum: Double?
        let maximum: Double?
        let loss: Double?
        let segment: Int
        let lossSegment: Int
    }

    let monitor: NetworkMonitorRecord
    let samples: [Sample]
    let averageLatency: Double?
    let packetLoss: Double?

    init(monitor: NetworkMonitorRecord, records: [NetworkMonitorStatsRecord], expectedInterval: TimeInterval) {
        self.monitor = monitor
        let records = records.filter { $0.monitor == monitor.id && $0.system == monitor.system && $0.created.isFinite }
            .sorted { $0.created < $1.created }
        var segment = 0
        var lossSegment = 0
        var previous: Date?
        var samples: [Sample] = []
        for record in records {
            if let previous, record.date.timeIntervalSince(previous) > expectedInterval * 1.8 {
                segment += 1
                lossSegment += 1
            }
            if record.loss == nil { lossSegment += 1 }
            if record.latency == nil { segment += 1 }
            samples.append(Sample(
                id: record.id, date: record.date, average: record.latency,
                minimum: record.latency != nil && record.responseMin.isFinite && record.responseMin >= 0 ? record.responseMin / 1000 : nil,
                maximum: record.latency != nil && record.responseMax.isFinite && record.responseMax >= 0 ? record.responseMax / 1000 : nil,
                loss: record.loss, segment: segment, lossSegment: lossSegment
            ))
            previous = record.date
        }
        self.samples = samples
        let valid = records.filter(\.validCounts)
        let total = valid.reduce(0.0) { $0 + Double($1.totalCount) }
        let successful = valid.filter { $0.latency != nil }
        let successes = successful.reduce(0.0) { $0 + Double($1.successCount) }
        averageLatency = successes > 0 ? successful.reduce(0) { $0 + $1.responseSum } / successes / 1000 : nil
        packetLoss = total > 0 ? (total - valid.reduce(0.0) { $0 + Double($1.successCount) }) / total * 100 : nil
    }
}

extension TimeRangeOption {
    // Unlike system_stats, monitor history stores created as Unix milliseconds.
    nonisolated func networkMonitorFilter(now: Date = .now) -> String {
        let duration: TimeInterval
        switch self {
        case .lastHour: duration = 3600
        case .last12Hours: duration = 43_200
        case .last24Hours: duration = 86_400
        case .last7Days: duration = 604_800
        case .last30Days: duration = 2_592_000
        }
        let start = Int64((now.timeIntervalSince1970 - duration - expectedInterval) * 1000)
        return "created >= \(start) && type = '\(recordType)'"
    }
}
