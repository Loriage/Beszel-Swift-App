import Foundation
import SwiftUI
import Observation
import LocalAuthentication

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

@Observable
@MainActor
final class SettingsManager {
    var selectedTimeRange: TimeRangeOption {
        didSet {
            UserDefaults.sharedSuite.set(selectedTimeRange.rawValue, forKey: "selectedTimeRange")
        }
    }

    var selectedTheme: AppTheme {
        didSet {
            UserDefaults.sharedSuite.set(selectedTheme.rawValue, forKey: "selectedTheme")
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
        if let savedTheme = UserDefaults.sharedSuite.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            self.selectedTheme = theme
        } else {
            self.selectedTheme = .system
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
