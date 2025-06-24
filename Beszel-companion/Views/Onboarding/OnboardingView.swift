import SwiftUI

struct OnboardingView: View {
    @State private var url = ""
    @State private var email = ""
    @State private var password = ""

    @State private var isLoading = false
    @State private var errorMessage: String?

    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "server.rack")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("onboarding.title")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("onboarding.subtitle")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            GroupBox {
                TextField("onboarding.urlPlaceholder", text: $url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                Divider()
                TextField("onboarding.input.email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                Divider()
                SecureField("onboarding.input.password", text: $password)
            }
            .padding(.horizontal)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: connect) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("onboarding.loginButton")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            .disabled(isLoading)

            Spacer()
            Spacer()
        }
    }

    private func connect() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let testService = BeszelAPIService(url: url, email: email, password: password)
                _ = try await testService.fetchMonitors(filter: nil)

                CredentialsManager.shared.saveCredentials(url: url, email: email, password: password)
                CredentialsManager.shared.setOnboardingCompleted(true)

                await MainActor.run {
                    onComplete()
                }
            } catch {
                errorMessage = "onboarding.loginFailed"
                isLoading = false
            }
        }
    }
}
