import SwiftUI
import AuthenticationServices
import Security

struct OnboardingLoginView: View {
    let instanceName: String
    let url: String
    let authMethods: AuthMethodsResponse
    let clientCert: ClientCertificatePayload?
    let initialEmail: String
    var onComplete: (String, String, String, String, ClientCertificatePayload?) -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var mfaState: MFAState?

    struct MFAState: Identifiable {
        let id = UUID()
        let mfaId: String
        let otpId: String?
        let email: String?
    }

    private var appIcon: UIImage? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String],
            let name = files.last
        else { return nil }
        return UIImage(named: name)
    }

    private var apiService: OnboardingAPIService { OnboardingAPIService(clientIdentity: clientCert?.identity) }
    private let contextProvider = WebAuthSessionContextProvider()

    private var isPasswordLoginDisabled: Bool {
        email.isEmpty || password.isEmpty
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            if let icon = appIcon {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            } else {
                Image(systemName: "server.rack")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)
            }

            Text(instanceName)
                .font(.largeTitle)
                .fontWeight(.bold)

            if authMethods.password.enabled {
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
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(isPasswordLoginDisabled || isLoading)
            }

            if authMethods.oauth2.enabled && !authMethods.oauth2.providers.isEmpty {
                if authMethods.password.enabled {
                    HStack {
                        VStack { Divider() }
                        Text("common.or")
                            .foregroundStyle(.secondary)
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

            if isLoading {
                ProgressView()
            }

            if let errorMessage = errorMessage {
                Text(LocalizedStringKey(errorMessage))
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            email = initialEmail
        }
        .sheet(item: $mfaState) { state in
            MFAView(
                url: url,
                mfaId: state.mfaId,
                otpId: state.otpId,
                email: state.email,
                clientIdentity: clientCert?.identity,
                onComplete: { token in
                    mfaState = nil
                    onComplete(instanceName, url, state.email ?? email, token, clientCert)
                },
                onCancel: {
                    mfaState = nil
                }
            )
        }
    }

    private func connectWithPassword() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await apiService.verifyCredentials(url: url, email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    onComplete(instanceName, url, email, password, clientCert)
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

                let (accessToken, userEmail) = try await apiService.exchangeCodeForToken(code: code, provider: provider, hubURL: url)

                self.isLoading = false
                onComplete(instanceName, url, userEmail, accessToken, clientCert)

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
