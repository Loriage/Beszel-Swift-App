import SwiftUI
@preconcurrency import AuthenticationServices
import Combine

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var instanceName = ""
    @Published var url = ""
    @Published var email = ""
    @Published var password = ""

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var authMethods: AuthMethodsResponse?
    
    var onComplete: (String, String, String, String) -> Void
    
    private let apiService = OnboardingAPIService()
    private let contextProvider = WebAuthSessionContextProvider()

    init(onComplete: @escaping (String, String, String, String) -> Void) {
        self.onComplete = onComplete
    }
    
    var isPasswordLoginDisabled: Bool {
        instanceName.isEmpty || url.isEmpty || email.isEmpty || password.isEmpty
    }

    func fetchAuthMethods() {
        guard !url.isEmpty else {
            self.errorMessage = String(localized: "onboarding.error.invalid_url")
            return
        }
        
        isLoading = true
        authMethods = nil
        errorMessage = nil
        
        Task {
            do {
                let methods = try await apiService.fetchAuthMethods(from: url)
                self.authMethods = methods
            } catch {
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(localized: "common.error.unknown")
            }
            self.isLoading = false
        }
    }

    func connectWithPassword() {
        onComplete(instanceName, url, email, password)
    }

    func startWebLogin(provider: OAuth2Provider) {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let appRedirectURL = "beszel-companion://redirect"
                guard let encodedRedirectURL = appRedirectURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let authURL = URL(string: "\(provider.authUrl)\(encodedRedirectURL)") else {
                    throw OnboardingAPIService.OnboardingError.invalidURL
                }

                let callbackURL = try await ASWebAuthenticationSession.async(
                    url: authURL,
                    callbackURLScheme: "beszel-companion",
                    presentationContextProvider: self.contextProvider
                )
                
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    throw URLError(.badServerResponse)
                }

                let (accessToken, userEmail) = try await apiService.exchangeCodeForToken(code: code, provider: provider, hubURL: self.url)
                
                self.isLoading = false
                onComplete(self.instanceName, self.url, userEmail, accessToken)
                
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

class WebAuthSessionContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        guard let window = windowScene?.windows.first(where: { $0.isKeyWindow }) else {
            fatalError("No key window available")
        }
        return window
    }
}

extension ASWebAuthenticationSession {
    static func async(url: URL, callbackURLScheme: String?, presentationContextProvider: ASWebAuthenticationPresentationContextProviding) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme) { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }
            session.presentationContextProvider = presentationContextProvider
            session.prefersEphemeralWebBrowserSession = true
            
            DispatchQueue.main.async {
                session.start()
            }
        }
    }
}
