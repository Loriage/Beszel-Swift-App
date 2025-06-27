import Foundation
import SwiftUI
import Combine

struct Language: Hashable {
    let code: String
    let name: String
}

class LanguageManager: ObservableObject {
    @AppStorage("selectedLanguage", store: .sharedSuite)
    var currentLanguageCode: String = ""
    
    let availableLanguages: [Language]

    init() {
        let supportedLanguageCodes = Bundle.main.localizations

        self.availableLanguages = supportedLanguageCodes.compactMap {
            let locale = Locale(identifier: $0)
            guard let name = locale.localizedString(forIdentifier: $0) else { return nil }
            return Language(code: $0, name: name.capitalized)
        }

        if currentLanguageCode.isEmpty {
            if let bestMatch = Bundle.preferredLocalizations(from: supportedLanguageCodes).first {
                self.currentLanguageCode = bestMatch
            } else {
                self.currentLanguageCode = Bundle.main.developmentLocalization ?? "en"
            }
        }
    }
}
