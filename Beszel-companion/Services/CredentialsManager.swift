//
//  CredentialsManager.swift
//  Beszel-companion
//
//  Created by Bruno DURAND on 20/06/2025.
//

import Foundation

class CredentialsManager {
    static let shared = CredentialsManager()

    private let service = "com.votre-nom.Beszel-companion"
    private let userAccount = "beszelUser"

    func saveCredentials(url: String, email: String, password: String) {
        UserDefaults.standard.set(url, forKey: "beszelURL")
        UserDefaults.standard.set(email, forKey: "beszelEmail")

        // On convertit le mot de passe en Data pour le Keychain
        if let passwordData = password.data(using: .utf8) {
            KeychainHelper.save(data: passwordData, service: service, account: userAccount)
        }
    }

    func loadCredentials() -> (url: String?, email: String?, password: String?) {
        let url = UserDefaults.standard.string(forKey: "beszelURL")
        let email = UserDefaults.standard.string(forKey: "beszelEmail")

        var password: String?
        if let passwordData = KeychainHelper.load(service: service, account: userAccount) {
            password = String(data: passwordData, encoding: .utf8)
        }
        return (url, email, password)
    }
    
    func deleteCredentials() {
        UserDefaults.standard.removeObject(forKey: "beszelURL")
        UserDefaults.standard.removeObject(forKey: "beszelEmail")
        KeychainHelper.delete(service: service, account: userAccount)
    }

    func setOnboardingCompleted(_ completed: Bool) {
        UserDefaults.standard.set(completed, forKey: "isOnboardingCompleted")
    }
}
