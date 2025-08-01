import Foundation
import SwiftUI
import Combine

class SettingsManager: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()
    @AppStorage("selectedTimeRange", store: .sharedSuite)
    var selectedTimeRange: TimeRangeOption = .last24Hours {
            didSet {
                objectWillChange.send()
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

        let filter = "created >= '\(dateString)'"
        return filter
    }
}
