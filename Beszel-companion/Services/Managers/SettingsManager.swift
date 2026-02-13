import Foundation
import SwiftUI
import Observation
import LocalAuthentication

@Observable
@MainActor
final class SettingsManager {
    var selectedTimeRange: TimeRangeOption {
        didSet {
            UserDefaults.sharedSuite.set(selectedTimeRange.rawValue, forKey: "selectedTimeRange")
        }
    }

    var appLockEnabled: Bool {
        didSet {
            UserDefaults.sharedSuite.set(appLockEnabled, forKey: "appLockEnabled")
        }
    }

    init() {
        if let savedValue = UserDefaults.sharedSuite.string(forKey: "selectedTimeRange"),
           let option = TimeRangeOption(rawValue: savedValue) {
            self.selectedTimeRange = option
        } else {
            self.selectedTimeRange = .last24Hours
        }
        self.appLockEnabled = UserDefaults.sharedSuite.bool(forKey: "appLockEnabled")
    }

    nonisolated func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(localized: "settings.security.appLock.reason")
            )
        } catch {
            return false
        }
    }
}
