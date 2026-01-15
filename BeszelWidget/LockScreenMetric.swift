import Foundation

enum LockScreenMetric: String, CaseIterable, Sendable {
    case cpu
    case memory
    case disk

    init(metric: MetricEntity?) {
        guard let metric, let resolved = LockScreenMetric(rawValue: metric.id) else {
            self = .cpu
            return
        }
        self = resolved
    }

    var shortLabel: String {
        switch self {
        case .cpu:
            return "CPU"
        case .memory:
            return "MEM"
        case .disk:
            return "DSK"
        }
    }

    func value(from stats: SystemStatsDetail) -> Double {
        switch self {
        case .cpu:
            return stats.cpu
        case .memory:
            return stats.memoryPercent
        case .disk:
            return stats.diskPercent
        }
    }
}
