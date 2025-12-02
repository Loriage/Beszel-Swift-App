import Foundation

extension UserDefaults {
    static var sharedSuite: UserDefaults {
        return UserDefaults(suiteName: "group.com.nohitdev.Beszel")!
    }
}
