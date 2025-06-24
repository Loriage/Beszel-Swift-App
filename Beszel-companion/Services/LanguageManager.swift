import Foundation
import SwiftUI
import Combine

struct Language: Hashable {
    let code: String
    let name: String
}

class LanguageManager: ObservableObject {
    @Published var currentLanguageCode: String

    let availableLanguages: [Language]
    
    private let appGroupIdentifier = "group.com.nohitdev.Beszel"
    private lazy var sharedUserDefaults = UserDefaults(suiteName: appGroupIdentifier)!
    private let userDefaultsKey = "selectedLanguage"

    init() {
        let supportedLanguageCodes = Bundle.main.localizations

        self.availableLanguages = supportedLanguageCodes.compactMap {
            let locale = Locale(identifier: $0)
            guard let name = locale.localizedString(forIdentifier: $0) else { return nil }
            return Language(code: $0, name: name.capitalized)
        }

        if let savedLanguage = CredentialsManager.sharedUserDefaults.string(forKey: userDefaultsKey) {
            self.currentLanguageCode = savedLanguage
        } else {
            if let bestMatch = Bundle.preferredLocalizations(from: supportedLanguageCodes).first {
                self.currentLanguageCode = bestMatch
            } else {
                self.currentLanguageCode = Bundle.main.developmentLocalization ?? "en"
            }
        }
    }
    
    func changeLanguage(to code: String) {
        self.currentLanguageCode = code
        CredentialsManager.sharedUserDefaults.set(code, forKey: userDefaultsKey)
    }
}
