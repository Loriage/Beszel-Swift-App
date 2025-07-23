import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @StateObject var viewModel: OnboardingViewModel

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
                TextField("onboarding.instanceNamePlaceholder", text: $viewModel.instanceName)
                    .autocapitalization(.words)
                Divider()
                TextField("onboarding.urlPlaceholder", text: $viewModel.url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .onSubmit(viewModel.fetchAuthMethods)
            }
            .padding(.horizontal)

            if viewModel.isLoading {
                ProgressView()
            }

            if let authMethods = viewModel.authMethods {
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
                        Button("Se connecter avec \(provider.displayName)") {
                            viewModel.startWebLogin(provider: provider)
                        }
                    }
                }
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(LocalizedStringKey(errorMessage))
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }

    private var passwordLoginView: some View {
        Group {
            GroupBox {
                TextField("onboarding.input.email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                Divider()
                SecureField("onboarding.input.password", text: $viewModel.password)
            }
            .padding(.horizontal)
            
            Button(action: viewModel.connectWithPassword) {
                Text("onboarding.loginButton")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isPasswordLoginDisabled ? Color.gray : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .disabled(viewModel.isPasswordLoginDisabled)
        }
    }
}
