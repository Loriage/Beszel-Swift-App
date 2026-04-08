import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class LanguageManager {
    var currentLanguageCode: String {
        didSet {
            UserDefaults.sharedSuite.set(currentLanguageCode, forKey: "selectedLanguage")
            updateCurrentBundle()
        }
    }
    
    var currentBundle: Bundle = .main
    
    let availableLanguages: [Language]
    
    // Explicitly list ready languages — prevents partially-translated languages
    // (e.g. from Crowdin) from appearing in the picker before they're complete.
    private static let readyLanguageCodes: Set<String> = ["en", "fr", "pl"]

    init() {
        let supportedLanguageCodes = Bundle.main.localizations

        self.availableLanguages = supportedLanguageCodes.compactMap {
            guard Self.readyLanguageCodes.contains($0) else { return nil }
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
        
        updateCurrentBundle()
    }
    
    private func updateCurrentBundle() {
        if let path = Bundle.main.path(forResource: currentLanguageCode, ofType: "lproj"),
           let specificBundle = Bundle(path: path) {
            self.currentBundle = specificBundle
        } else {
            self.currentBundle = .main
        }
    }
}
