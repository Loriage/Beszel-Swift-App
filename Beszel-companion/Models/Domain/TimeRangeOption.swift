import Foundation

enum TimeRangeOption: String, CaseIterable, Identifiable, Sendable {
    case lastHour = "timeRange.lastHour"
    case last12Hours = "timeRange.last12Hours"
    case last24Hours = "timeRange.last24Hours"
    case last7Days = "timeRange.last7Days"
    case last30Days = "timeRange.last30Days"
    
    var id: String { self.rawValue }
}

extension TimeRangeOption {
    var xAxisFormat: Date.FormatStyle {
        switch self {
        case .lastHour, .last12Hours:
            return .dateTime.hour(.defaultDigits(amPM: .omitted)).minute()
        case .last24Hours:
            return .dateTime.hour().minute()
        case .last7Days, .last30Days:
            return .dateTime.day(.twoDigits).month(.twoDigits)
        }
    }

    var xDomain: ClosedRange<Date> {
        let now = Date()
        let start: Date
        switch self {
        case .lastHour:
            start = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now
        case .last12Hours:
            start = Calendar.current.date(byAdding: .hour, value: -12, to: now) ?? now
        case .last24Hours:
            start = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        case .last7Days:
            start = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        case .last30Days:
            start = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        }
        return start...now
    }
    
    var recordType: String {
        switch self {
        case .lastHour: return "1m"
        default: return "20m"
        }
    }

    /// Interval buffer added before the window start to ensure the chart has a data point at the left edge.
    private var fetchBuffer: TimeInterval {
        recordType == "1m" ? 60 : 20 * 60
    }

    var apiFilterString: String {
        let now = Date()
        let windowStart: Date

        switch self {
        case .lastHour:
            windowStart = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now
        case .last12Hours:
            windowStart = Calendar.current.date(byAdding: .hour, value: -12, to: now) ?? now
        case .last24Hours:
            windowStart = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        case .last7Days:
            windowStart = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        case .last30Days:
            windowStart = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        }

        // Fetch one record-interval before the domain start so the chart line reaches the left edge
        let startDate = windowStart.addingTimeInterval(-fetchBuffer)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateString = formatter.string(from: startDate)

        return "created >= '\(dateString)' && type = '\(recordType)'"
    }
    
    var refreshInterval: TimeInterval {
        switch self {
        case .lastHour: return 60
        case .last12Hours: return 30 * 60
        case .last24Hours, .last7Days, .last30Days: return 60 * 60
        }
    }
    
    var fastRefreshInterval: TimeInterval {
        return 12
    }
}
