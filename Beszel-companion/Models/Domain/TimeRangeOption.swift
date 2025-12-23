import Foundation

enum TimeRangeOption: String, CaseIterable, Identifiable {
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
        case .lastHour, .last12Hours, .last24Hours:
            return .dateTime.hour(.defaultDigits(amPM: .omitted)).minute()
        case .last7Days, .last30Days:
            return .dateTime.day(.twoDigits).month(.twoDigits)
        }
    }
    
    var apiFilterString: String {
        let now = Date().addingTimeInterval(5 * 60)
        let startDate: Date
        
        switch self {
        case .lastHour:
            startDate = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now
        case .last12Hours:
            startDate = Calendar.current.date(byAdding: .hour, value: -12, to: now) ?? now
        case .last24Hours:
            startDate = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        case .last7Days:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        case .last30Days:
            startDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateString = formatter.string(from: startDate)
        
        return "created >= '\(dateString)'"
    }
    
    var refreshInterval: TimeInterval {
        switch self {
        case .lastHour: return 60
        case .last12Hours: return 30 * 60
        case .last24Hours, .last7Days, .last30Days: return 60 * 60
        }
    }
}
