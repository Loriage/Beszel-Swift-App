import Foundation
import SwiftUI
import Combine

enum TimeRangeOption: String, CaseIterable, Identifiable {
    case lastHour = "lastHour"
    case last12Hours = "last12Hours"
    case last24Hours = "last24Hours"
    case last7Days = "last7Days"
    case last30Days = "last30Days"

    var id: String { self.rawValue }
}

class SettingsManager: ObservableObject {
    @AppStorage("selectedTimeRange", store: CredentialsManager.sharedUserDefaults)
    var selectedTimeRange: TimeRangeOption = .last24Hours

    var apiFilterString: String? {
        let now = Date().addingTimeInterval(5 * 60)
        var startDate: Date?

        switch selectedTimeRange {
        case .lastHour:
            startDate = Calendar.current.date(byAdding: .hour, value: -1, to: now)
        case .last12Hours:
            startDate = Calendar.current.date(byAdding: .hour, value: -12, to: now)
        case .last24Hours:
            startDate = Calendar.current.date(byAdding: .day, value: -1, to: now)
        case .last7Days:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: now)
        case .last30Days:
            startDate = Calendar.current.date(byAdding: .day, value: -30, to: now)
        }

        guard let startDate = startDate else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateString = formatter.string(from: startDate)

        let filter = "created >= '\(dateString)'"
        return filter.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }
}
