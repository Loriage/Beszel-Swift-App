import Foundation
import os

nonisolated private let logger = Logger(subsystem: "com.nohitdev.Beszel", category: "UserDefaults")

extension UserDefaults: @retroactive @unchecked Sendable {}

extension UserDefaults {
    nonisolated static var sharedSuite: UserDefaults {
        guard let suite = UserDefaults(suiteName: Constants.appGroupId) else {
            // Fallback to standard UserDefaults if app group is misconfigured
            // This prevents crashes but may cause widget data sync issues
            logger.error("App group '\(Constants.appGroupId)' is not available. Widget data sync will not work. Please check your entitlements configuration.")
            return UserDefaults.standard
        }
        return suite
    }
}
