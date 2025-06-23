import Foundation

class CredentialsManager {
    static let shared = CredentialsManager()

    let appGroupIdentifier = "group.com.nohitdev.Beszel"
    private lazy var sharedUserDefaults = UserDefaults(suiteName: appGroupIdentifier)!

    private let service = "com.nohitdev.Beszel"
    private let userAccount = "beszelUser"

    func saveCredentials(url: String, email: String, password: String) {
        sharedUserDefaults.set(url, forKey: "beszelURL")
        sharedUserDefaults.set(email, forKey: "beszelEmail")

        if let passwordData = password.data(using: .utf8) {
            KeychainHelper.save(data: passwordData, service: service, account: userAccount)
        }
    }

    func loadCredentials() -> (url: String?, email: String?, password: String?) {
        let url = sharedUserDefaults.string(forKey: "beszelURL")
        let email = sharedUserDefaults.string(forKey: "beszelEmail")

        var password: String?
        if let passwordData = KeychainHelper.load(service: service, account: userAccount) {
            password = String(data: passwordData, encoding: .utf8)
        }
        return (url, email, password)
    }

    func deleteCredentials() {
        sharedUserDefaults.removeObject(forKey: "beszelURL")
        sharedUserDefaults.removeObject(forKey: "beszelEmail")

        KeychainHelper.delete(service: service, account: userAccount)
    }
    
    func setOnboardingCompleted(_ completed: Bool) {
        sharedUserDefaults.set(completed, forKey: "isOnboardingCompleted")
    }
}
