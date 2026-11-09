import SwiftUI

struct ReauthenticationView: View {
    let instance: Instance
    let onComplete: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var methods: AuthMethodsResponse?
    @State private var errorMessage: String?
    @State private var requestID = UUID()

    private var advanced: InstanceAdvancedOptions { .stored(for: instance) }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("authentication.signInAgain")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { dismiss() }
                            .accessibilityIdentifier("reauthentication.cancel")
                    }
                }
                .task(id: requestID) { await loadMethods() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let methods {
            OnboardingLoginView(
                instanceName: instance.name,
                url: instance.url,
                authMethods: methods,
                advanced: advanced,
                initialEmail: instance.email
            ) { _, _, email, credential, _ in
                onComplete(email, credential)
            }
            .accessibilityIdentifier("reauthentication.login")
        } else if let errorMessage {
            MonitoringStateView(state: .failure(errorMessage)) {
                self.errorMessage = nil
                requestID = UUID()
            }
        } else {
            MonitoringStateView(state: .loading("authentication.loading"))
        }
    }

    private func loadMethods() async {
        let options = advanced
        let api = OnboardingAPIService(baseURL: instance.url, fallbackURL: options.fallbackURL,
                                       clientIdentity: options.clientIdentity, caCertificate: options.caCertificate,
                                       customHeaders: options.customHeaders)
        do {
            let response = try await api.fetchAuthMethods(from: instance.url)
            try Task.checkCancellation()
            methods = response
        } catch {
            guard !Task.isCancelled, (error as? URLError)?.code != .cancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}
