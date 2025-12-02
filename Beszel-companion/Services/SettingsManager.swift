import Foundation
import SwiftUI
import Observation

@Observable
final class SettingsManager {
    var selectedTimeRange: TimeRangeOption {
        didSet {
            UserDefaults.sharedSuite.set(selectedTimeRange.rawValue, forKey: "selectedTimeRange")
        }
    }

    init() {
        if let savedValue = UserDefaults.sharedSuite.string(forKey: "selectedTimeRange"),
           let option = TimeRangeOption(rawValue: savedValue) {
            self.selectedTimeRange = option
        } else {
            self.selectedTimeRange = .last24Hours
        }
    }

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

        return "created >= '\(dateString)'"
    }
}
