import Foundation

extension UserDefaults {
    static var sharedSuite: UserDefaults {
        guard let suite = UserDefaults(suiteName: Constants.appGroupId) else {
            // Fallback to standard UserDefaults if app group is misconfigured
            // This prevents crashes but may cause widget data sync issues
            return UserDefaults.standard
        }
        return suite
    }
}
