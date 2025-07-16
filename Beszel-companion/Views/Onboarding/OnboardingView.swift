import SwiftUI
@preconcurrency import AuthenticationServices

struct AuthMethodsResponse: Decodable {
    let password: PasswordAuth
    let oauth2: OAuth2Auth
}

struct PasswordAuth: Decodable {
    let enabled: Bool
}

struct OAuth2Auth: Decodable {
    let enabled: Bool
    let providers: [OAuth2Provider]
}

struct OAuth2Provider: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let displayName: String
    let authUrl: String
    let codeVerifier: String
}

private struct SSOUserRecord: Decodable {
    let email: String
}

class WebAuthSessionContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(
        for session: ASWebAuthenticationSession
    ) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        guard let window = windowScene?.windows.first(where: { $0.isKeyWindow })
        else {
            fatalError("No key window available")
        }
        return window
    }
}

struct OnboardingView: View {
    @State private var instanceName = ""
    @State private var url = ""
    @State private var email = ""
    @State private var password = ""

    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @State private var authMethods: AuthMethodsResponse?
    @State private var contextProvider = WebAuthSessionContextProvider()

    var onComplete: (String, String, String, String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "server.rack")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("onboarding.title")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            GroupBox {
                TextField("onboarding.instanceNamePlaceholder", text: $instanceName)
                    .autocapitalization(.words)
                Divider()
                TextField("onboarding.urlPlaceholder", text: $url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .onSubmit(fetchAuthMethods)
            }
            .padding(.horizontal)

            if isLoading {
                ProgressView()
            }

            if let authMethods = authMethods {
                if authMethods.password.enabled {
                    passwordLoginView
                }
                
                if authMethods.oauth2.enabled && !authMethods.oauth2.providers.isEmpty {
                    if authMethods.password.enabled {
                        HStack {
                            VStack { Divider() }
                            Text("ou")
                                .foregroundColor(.secondary)
                            VStack { Divider() }
                        }
                        .padding(.horizontal)
                    }
                    
                    ForEach(authMethods.oauth2.providers) { provider in
                        Button(action: {
                            startWebLogin(provider: provider)
                        }) {
                            Text("Se connecter avec \(provider.displayName)")
                        }
                    }
                }
            }
            
            if let errorMessage = errorMessage {
                Text(LocalizedStringKey(errorMessage))
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }

    private var isPasswordLoginDisabled: Bool {
        return instanceName.isEmpty || url.isEmpty || email.isEmpty || password.isEmpty
    }

    private var passwordLoginView: some View {
        Group {
            GroupBox {
                TextField("onboarding.input.email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                Divider()
                SecureField("onboarding.input.password", text: $password)
            }
            .padding(.horizontal)
            
            Button(action: connect) {
                Text("onboarding.loginButton")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isPasswordLoginDisabled ? Color.gray : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .disabled(isPasswordLoginDisabled)
        }
    }
    
    private func fetchAuthMethods() {
        guard !url.isEmpty, let hubURL = URL(string: url) else {
            self.errorMessage = "Veuillez entrer une URL valide."
            return
        }
        
        self.isLoading = true
        self.authMethods = nil
        self.errorMessage = nil
        
        Task {
            do {
                let requestURL = hubURL.appendingPathComponent("/api/collections/users/auth-methods")
                let (data, _) = try await URLSession.shared.data(from: requestURL)
                let decodedMethods = try JSONDecoder().decode(AuthMethodsResponse.self, from: data)
                
                await MainActor.run {
                    self.authMethods = decodedMethods
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Impossible de joindre le hub. Vérifiez l'URL et votre connexion."
                    self.isLoading = false
                }
            }
        }
    }

    private func startWebLogin(provider: OAuth2Provider) {
        Task {
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            do {
                let authorizationCodeURL = try await getAuthorizationCodeURL(for: provider)
                
                guard let components = URLComponents(url: authorizationCodeURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    throw URLError(.badServerResponse)
                }

                let (accessToken, userEmail) = try await exchangeCodeForToken(code: code, provider: provider)
                
                await MainActor.run {
                    self.isLoading = false
                    onComplete(self.instanceName, self.url, userEmail, accessToken)
                }
                
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func getAuthorizationCodeURL(for provider: OAuth2Provider) async throws -> URL {
        let appRedirectURL = "beszel-companion://redirect"
        
        guard let encodedRedirectURL = appRedirectURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.badURL)
        }
        
        let authURLString = "\(provider.authUrl)\(encodedRedirectURL)"
        
        guard let authURL = URL(string: authURLString) else {
            throw URLError(.badURL)
        }

        return try await ASWebAuthenticationSession.async(
            url: authURL,
            callbackURLScheme: "beszel-companion",
            presentationContextProvider: self.contextProvider
        )
    }

    private func exchangeCodeForToken(code: String, provider: OAuth2Provider) async throws -> (token: String, email: String) {
        guard let tokenURL = URL(string: "\(self.url)/api/collections/users/auth-with-oauth2") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct TokenRequestBody: Encodable {
            let provider: String
            let code: String
            let codeVerifier: String
            let redirectUrl: String
        }
        
        let body = TokenRequestBody(
            provider: provider.name,
            code: code,
            codeVerifier: provider.codeVerifier,
            redirectUrl: "beszel-companion://redirect"
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        struct TokenResponseBody: Decodable {
            let token: String
            let record: SSOUserRecord
        }
        
        let responseBody = try JSONDecoder().decode(TokenResponseBody.self, from: data)
        return (responseBody.token, responseBody.record.email)
    }

    private func connect() {
        onComplete(instanceName, url, email, password)
    }
}

extension ASWebAuthenticationSession {
    static func async(url: URL, callbackURLScheme: String?, presentationContextProvider: ASWebAuthenticationPresentationContextProviding) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
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
