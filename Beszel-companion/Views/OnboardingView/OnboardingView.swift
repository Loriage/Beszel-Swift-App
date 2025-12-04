import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @State var viewModel: OnboardingViewModel
    
    var body: some View {
        @Bindable var bindableViewModel = viewModel
        
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "server.rack")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("onboarding.title")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack {
                TextField("onboarding.instanceNamePlaceholder", text: $bindableViewModel.instanceName)
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(10)
                
                HStack(spacing: 10) {
                    Picker("Scheme", selection: $viewModel.selectedScheme) {
                        ForEach(OnboardingViewModel.ServerScheme.allCases) { scheme in
                            Text(scheme.rawValue).tag(scheme)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(height: 54)
                    .background(.thinMaterial)
                    .cornerRadius(10)
                    .tint(Color.primary)
                    
                    TextField("onboarding.urlPlaceholder", text: $bindableViewModel.serverAddress)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(10)
                        .onSubmit {
                            viewModel.fetchAuthMethods()
                        }
                }
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
                            Text("common.or")
                                .foregroundColor(.secondary)
                            VStack { Divider() }
                        }
                        .padding(.horizontal)
                    }
                    
                    ForEach(authMethods.oauth2.providers) { provider in
                        Button(.init(String(format: String(localized: "onboarding.connect_with_provider"), provider.displayName))) {
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
        @Bindable var bindableViewModel = viewModel
        
        return Group {
            VStack {
                TextField("onboarding.input.email", text: $bindableViewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(10)
                
                SecureField("onboarding.input.password", text: $bindableViewModel.password)
                    .textContentType(.password)
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(10)
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
