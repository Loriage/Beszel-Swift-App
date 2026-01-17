import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
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
}
