import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    var editingInstance: Instance?
    var onComplete: (String, String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var instanceName = ""
    @State private var selectedScheme: ServerScheme = .https
    @State private var serverAddress = ""
    @State private var email = ""
    @State private var password = ""

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var authMethods: AuthMethodsResponse?

    @State private var mfaState: MFAState?

    struct MFAState: Identifiable {
        let id = UUID()
        let mfaId: String
        let otpId: String?
        let email: String?
    }

    private let apiService = OnboardingAPIService()
    private let contextProvider = WebAuthSessionContextProvider()

    private var isEditing: Bool { editingInstance != nil }

    enum ServerScheme: String, CaseIterable, Identifiable {
        case http = "http://"
        case https = "https://"
        var id: String { self.rawValue }
    }
    
    private var url: String {
        selectedScheme.rawValue + serverAddress
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
    }

    private var isValidURL: Bool {
        guard !serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard let urlComponents = URLComponents(string: url),
              let host = urlComponents.host,
              !host.isEmpty else {
            return false
        }
        return true
    }
    
    private var isPasswordLoginDisabled: Bool {
        instanceName.isEmpty || url.isEmpty || email.isEmpty || password.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "server.rack")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("onboarding.title")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack {
                    TextField("onboarding.instanceNamePlaceholder", text: $instanceName)
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(10)
                    
                    HStack(spacing: 10) {
                        Picker("Scheme", selection: $selectedScheme) {
                            ForEach(ServerScheme.allCases) { scheme in
                                Text(scheme.rawValue).tag(scheme)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(height: 54)
                        .background(.thinMaterial)
                        .cornerRadius(10)
                        .tint(Color.primary)
                        
                        TextField("onboarding.urlPlaceholder", text: $serverAddress)
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .padding()
                            .background(.thinMaterial)
                            .cornerRadius(10)
                            .onSubmit {
                                fetchAuthMethods()
                            }
                    }
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
                                Text("common.or")
                                    .foregroundColor(.secondary)
                                VStack { Divider() }
                            }
                            .padding(.horizontal)
                        }
                        
                        ForEach(authMethods.oauth2.providers) { provider in
                            Button(.init(String(format: String(localized: "onboarding.connect_with_provider"), provider.displayName))) {
                                startWebLogin(provider: provider)
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
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
            }
            .onAppear {
                if let instance = editingInstance {
                    instanceName = instance.name
                    email = instance.email
                    if instance.url.hasPrefix("http://") {
                        selectedScheme = .http
                        serverAddress = String(instance.url.dropFirst(7))
                    } else if instance.url.hasPrefix("https://") {
                        selectedScheme = .https
                        serverAddress = String(instance.url.dropFirst(8))
                    } else {
                        serverAddress = instance.url
                    }
                    fetchAuthMethods()
                }
            }
            .sheet(item: $mfaState) { state in
                MFAView(
                    url: url,
                    mfaId: state.mfaId,
                    otpId: state.otpId,
                    email: state.email,
                    onComplete: { token in
                        mfaState = nil
                        onComplete(instanceName, url, state.email ?? email, token)
                    },
                    onCancel: {
                        mfaState = nil
                    }
                )
            }
        }
    }

    private var passwordLoginView: some View {
        Group {
            VStack {
                TextField("onboarding.input.email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(10)

                SecureField("onboarding.input.password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            Button(action: connectWithPassword) {
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
        guard isValidURL else {
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
    
    private func connectWithPassword() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await apiService.verifyCredentials(url: self.url, email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    onComplete(instanceName, url, email, password)
                }
            } catch OnboardingAPIService.OnboardingError.mfaRequired(let mfaId, let otpId) {
                await MainActor.run {
                    isLoading = false
                    self.mfaState = MFAState(mfaId: mfaId, otpId: otpId, email: email)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    self.errorMessage = String(localized: "onboarding.loginFailed")
                }
            }
        }
    }
    
    private func startWebLogin(provider: OAuth2Provider) {
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

            } catch OnboardingAPIService.OnboardingError.oauthMfaRequired(let mfaId) {
                self.isLoading = false
                self.mfaState = MFAState(mfaId: mfaId, otpId: nil, email: nil)
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
        
        if let keyWindow = windowScene?.windows.first(where: { $0.isKeyWindow }) {
            return keyWindow
        }
        if let anyWindow = windowScene?.windows.first {
            return anyWindow
        }
        
        return UIWindow()
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

            Task { @MainActor in
                session.start()
            }
        }
    }
}
