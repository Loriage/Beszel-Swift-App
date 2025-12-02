import Foundation
import SwiftUI
import Observation

@Observable
final class LanguageManager {
    var currentLanguageCode: String {
        didSet {
            UserDefaults.sharedSuite.set(currentLanguageCode, forKey: "selectedLanguage")
        }
    }
    
    let availableLanguages: [Language]

    init() {
        let supportedLanguageCodes = Bundle.main.localizations

        self.availableLanguages = supportedLanguageCodes.compactMap {
            let locale = Locale(identifier: $0)
            guard let name = locale.localizedString(forIdentifier: $0) else { return nil }
            return Language(code: $0, name: name.capitalized)
        }
        
        let savedCode = UserDefaults.sharedSuite.string(forKey: "selectedLanguage") ?? ""

        if !savedCode.isEmpty {
            self.currentLanguageCode = savedCode
        } else if let bestMatch = Bundle.preferredLocalizations(from: supportedLanguageCodes).first {
            self.currentLanguageCode = bestMatch
        } else {
            self.currentLanguageCode = Bundle.main.developmentLocalization ?? "en"
        }
    }
}
