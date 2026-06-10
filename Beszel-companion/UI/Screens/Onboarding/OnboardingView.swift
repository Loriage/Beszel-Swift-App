import SwiftUI
import AuthenticationServices
import Security
import UniformTypeIdentifiers

struct OnboardingView: View {
    var editingInstance: Instance?
    var onComplete: (String, String, String, String, ClientCertificatePayload?, ServerCACertificatePayload?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var instanceName = ""
    @State private var selectedScheme: ServerScheme = .https
    @State private var serverAddress = ""

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var authMethods: AuthMethodsResponse?
    @State private var navigateToLogin = false

    @State private var selectedCert: ClientCertificatePayload?
    @State private var selectedCertSubject: String?
    @State private var isShowingCertPicker = false
    @State private var pendingCertData: Data?
    @State private var certPassword = ""
    @State private var isShowingCertPasswordAlert = false
    @State private var certImportError: String?
    @State private var isAdvancedExpanded = false

    @State private var selectedCACert: ServerCACertificatePayload?
    @State private var selectedCACertSubject: String?
    @State private var isShowingCAPicker = false
    @State private var caImportError: String?

    private var appIcon: UIImage? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String],
            let name = files.last
        else { return nil }
        return UIImage(named: name)
    }

    private var apiService: OnboardingAPIService { OnboardingAPIService(clientIdentity: selectedCert?.identity, caCertificate: selectedCACert?.certificate) }

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

    private var isContinueDisabled: Bool {
        instanceName.isEmpty || !isValidURL
    }

    private static let clientCertTypes: [UTType] = [
        UTType(filenameExtension: "p12") ?? .data,
        UTType(filenameExtension: "pfx") ?? .data
    ]

    private static let caCertTypes: [UTType] = [
        .x509Certificate,
        UTType(filenameExtension: "pem") ?? .data,
        UTType(filenameExtension: "crt") ?? .data,
        UTType(filenameExtension: "cer") ?? .data,
        UTType(filenameExtension: "der") ?? .data
    ]

    var body: some View {
        NavigationStack {
            content
                .toolbar { toolbarContent }
                .onAppear { applyEditingInstanceIfNeeded() }
                .navigationDestination(isPresented: $navigateToLogin) { loginDestination }
                .fileImporter(isPresented: $isShowingCertPicker, allowedContentTypes: Self.clientCertTypes) { result in
                    if case .success(let url) = result { handleCertFileSelected(url) }
                }
                .fileImporter(isPresented: $isShowingCAPicker, allowedContentTypes: Self.caCertTypes) { result in
                    if case .success(let url) = result { handleCACertFileSelected(url) }
                }
                .alert("onboarding.advanced.enterCertPassword", isPresented: $isShowingCertPasswordAlert) {
                    passwordAlertActions
                }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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

    @ViewBuilder
    private var loginDestination: some View {
        if let methods = authMethods {
            OnboardingLoginView(
                instanceName: instanceName,
                url: url,
                authMethods: methods,
                clientCert: selectedCert,
                caCert: selectedCACert,
                initialEmail: editingInstance?.email ?? "",
                onComplete: onComplete
            )
        }
    }

    @ViewBuilder
    private var passwordAlertActions: some View {
        SecureField("onboarding.advanced.certPasswordPlaceholder", text: $certPassword)
        Button("common.cancel", role: .cancel) {
            certPassword = ""
            pendingCertData = nil
        }
        Button("onboarding.advanced.import") { importCertificate() }
    }

    private func applyEditingInstanceIfNeeded() {
        guard let instance = editingInstance else { return }
        instanceName = instance.name
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

    private var content: some View {
        VStack(spacing: 20) {
            Spacer()

            headerView

            serverInputFields

            clientCertificateSection

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

            Button(action: fetchAuthMethods) {
                Text("onboarding.continueButton")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isContinueDisabled ? Color.gray : Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .disabled(isContinueDisabled || isLoading)

            Spacer()
        }
    }

    @ViewBuilder
    private var headerView: some View {
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

        Text("onboarding.title")
            .font(.largeTitle)
            .fontWeight(.bold)
    }

    private var serverInputFields: some View {
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
                        if !isContinueDisabled { fetchAuthMethods() }
                    }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var clientCertificateSection: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAdvancedExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("onboarding.advanced.title")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isAdvancedExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isAdvancedExpanded {
                certificateRow(
                    icon: "lock.shield",
                    subjectLabel: "onboarding.advanced.clientCertificate",
                    emptyLabel: "onboarding.advanced.importCertificate",
                    subject: selectedCertSubject,
                    onTap: { isShowingCertPicker = true },
                    onClear: {
                        selectedCert = nil
                        selectedCertSubject = nil
                    }
                )

                if let certError = certImportError {
                    certificateError(certError)
                }

                certificateRow(
                    icon: "checkmark.seal",
                    subjectLabel: "onboarding.advanced.serverCA",
                    emptyLabel: "onboarding.advanced.importServerCA",
                    subject: selectedCACertSubject,
                    onTap: { isShowingCAPicker = true },
                    onClear: {
                        selectedCACert = nil
                        selectedCACertSubject = nil
                    }
                )

                if let caError = caImportError {
                    certificateError(caError)
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func certificateRow(
        icon: String,
        subjectLabel: LocalizedStringKey,
        emptyLabel: LocalizedStringKey,
        subject: String?,
        onTap: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        let isSet = subject != nil
        Button(action: { if !isSet { onTap() } }) {
            HStack(spacing: 12) {
                Image(systemName: isSet ? "\(icon).fill" : icon)
                    .font(.body)
                    .foregroundStyle(isSet ? Color.accentColor : Color.secondary)
                    .frame(width: 24)

                if let subject {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(subjectLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(subject)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                } else {
                    Text(emptyLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSet {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.thinMaterial)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func certificateError(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(.red)
            .font(.caption)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .transition(.opacity)
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
                self.navigateToLogin = true
            } catch {
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(localized: "common.error.unknown")
            }
            self.isLoading = false
        }
    }

    private func handleCertFileSelected(_ fileURL: URL) {
        guard fileURL.startAccessingSecurityScopedResource() else { return }
        defer { fileURL.stopAccessingSecurityScopedResource() }
        do {
            pendingCertData = try Data(contentsOf: fileURL)
            isShowingCertPasswordAlert = true
        } catch {
            certImportError = error.localizedDescription
        }
    }

    private func handleCACertFileSelected(_ fileURL: URL) {
        guard fileURL.startAccessingSecurityScopedResource() else { return }
        defer { fileURL.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: fileURL)
            guard let certificate = ServerCACertificateManager.parseCertificate(from: data) else {
                caImportError = String(localized: "mtls.error.invalidCertificate")
                return
            }
            let der = SecCertificateCopyData(certificate) as Data
            selectedCACert = ServerCACertificatePayload(certificate: certificate, certData: der)
            selectedCACertSubject = SecCertificateCopySubjectSummary(certificate) as String?
            caImportError = nil
        } catch {
            caImportError = error.localizedDescription
        }
    }

    private func importCertificate() {
        guard let data = pendingCertData else { return }
        do {
            let identity = try ClientCertificateManager.importIdentity(from: data, password: certPassword)
            var cert: SecCertificate?
            SecIdentityCopyCertificate(identity, &cert)
            selectedCert = ClientCertificatePayload(identity: identity, p12Data: data, password: certPassword)
            selectedCertSubject = cert.flatMap { SecCertificateCopySubjectSummary($0) as String? }
            certImportError = nil
        } catch {
            certImportError = error.localizedDescription
            selectedCert = nil
            selectedCertSubject = nil
        }
        certPassword = ""
        pendingCertData = nil
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
