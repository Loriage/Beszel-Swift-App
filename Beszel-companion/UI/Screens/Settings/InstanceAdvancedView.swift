import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

struct InstanceAdvancedView: View {
    let instance: Instance

    @Environment(\.dismiss) private var dismiss

    @State private var certSubject: String?
    @State private var isShowingFilePicker = false
    @State private var pendingCertData: Data?
    @State private var certPassword = ""
    @State private var isShowingPasswordAlert = false
    @State private var errorMessage: String?
    @State private var isShowingRemoveConfirm = false

    @State private var caSubject: String?
    @State private var isShowingCAFilePicker = false
    @State private var isShowingCARemoveConfirm = false
    @State private var caErrorMessage: String?

    @State private var customHeaders: [String: String] = [:]
    @State private var isShowingHeadersEditor = false

    var body: some View {
        NavigationStack {
            Form {
                InstanceFallbackURLSection(instanceID: instance.id, fallbackURL: instance.fallbackURL)

                Section {
                    if let subject = certSubject {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("mtls.certInstalled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(subject)
                        }

                        Button("mtls.removeCert", role: .destructive) {
                            isShowingRemoveConfirm = true
                        }
                    } else {
                        Button("mtls.importCert") {
                            isShowingFilePicker = true
                        }
                    }
                } header: {
                    Text("mtls.clientCertificate")
                } footer: {
                    Text("mtls.description")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    if let subject = caSubject {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("mtls.caInstalled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(subject)
                        }

                        Button("mtls.removeCA", role: .destructive) {
                            isShowingCARemoveConfirm = true
                        }
                    } else {
                        Button("mtls.importCA") {
                            isShowingCAFilePicker = true
                        }
                    }
                } header: {
                    Text("mtls.serverCertificate")
                } footer: {
                    Text("mtls.serverCADescription")
                }

                if let error = caErrorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    if customHeaders.isEmpty {
                        Button("headers.add") { isShowingHeadersEditor = true }
                    } else {
                        ForEach(customHeaders.keys.sorted(), id: \.self) { key in
                            HStack {
                                Text(key)
                                    .font(.subheadline)
                                Spacer()
                                Text("headers.valueHidden")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button("headers.edit") { isShowingHeadersEditor = true }
                    }
                } header: {
                    Text("headers.title")
                } footer: {
                    Text("headers.description")
                }
            }
            .navigationTitle("advanced.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                certSubject = ClientCertificateManager.certificateSubject(for: instance.id)
                caSubject = ServerCACertificateManager.certificateSubject(for: instance.id)
                customHeaders = CustomHeadersManager.load(for: instance.id)
            }
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "p12") ?? .data,
                UTType(filenameExtension: "pfx") ?? .data
            ]
        ) { result in
            if case .success(let url) = result {
                handleFileSelected(url)
            }
        }
        .fileImporter(
            isPresented: $isShowingCAFilePicker,
            allowedContentTypes: [
                .x509Certificate,
                UTType(filenameExtension: "pem") ?? .data,
                UTType(filenameExtension: "crt") ?? .data,
                UTType(filenameExtension: "cer") ?? .data,
                UTType(filenameExtension: "der") ?? .data
            ]
        ) { result in
            if case .success(let url) = result {
                handleCAFileSelected(url)
            }
        }
        .alert("mtls.enterPassword", isPresented: $isShowingPasswordAlert) {
            SecureField("mtls.passwordPlaceholder", text: $certPassword)
            Button("common.cancel", role: .cancel) {
                certPassword = ""
                pendingCertData = nil
            }
            Button("mtls.import") { importCert() }
        }
        .alert("mtls.confirmRemove", isPresented: $isShowingRemoveConfirm) {
            Button("common.cancel", role: .cancel) {}
            Button("common.delete", role: .destructive) { removeCert() }
        }
        .alert("mtls.confirmRemoveCA", isPresented: $isShowingCARemoveConfirm) {
            Button("common.cancel", role: .cancel) {}
            Button("common.delete", role: .destructive) { removeCACert() }
        }
        .sheet(isPresented: $isShowingHeadersEditor) {
            CustomHeadersEditorView(headers: customHeaders) { headers in
                CustomHeadersManager.store(headers, for: instance.id)
                customHeaders = headers
            }
        }
    }

    private func handleCAFileSelected(_ fileURL: URL) {
        guard fileURL.startAccessingSecurityScopedResource() else { return }
        defer { fileURL.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: fileURL)
            try ServerCACertificateManager.importAndStore(certData: data, for: instance.id)
            caSubject = ServerCACertificateManager.certificateSubject(for: instance.id)
            caErrorMessage = nil
        } catch {
            caErrorMessage = error.localizedDescription
        }
    }

    private func removeCACert() {
        ServerCACertificateManager.delete(for: instance.id)
        caSubject = nil
    }

    private func handleFileSelected(_ fileURL: URL) {
        guard fileURL.startAccessingSecurityScopedResource() else { return }
        defer { fileURL.stopAccessingSecurityScopedResource() }
        do {
            pendingCertData = try Data(contentsOf: fileURL)
            isShowingPasswordAlert = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importCert() {
        guard let data = pendingCertData else { return }
        do {
            try ClientCertificateManager.importAndStore(p12Data: data, password: certPassword, for: instance.id)
            certSubject = ClientCertificateManager.certificateSubject(for: instance.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        certPassword = ""
        pendingCertData = nil
    }

    private func removeCert() {
        ClientCertificateManager.delete(for: instance.id)
        certSubject = nil
    }
}

private struct InstanceFallbackURLSection: View {
    let instanceID: UUID
    @Environment(InstanceManager.self) private var instanceManager
    @State private var fallbackURL: String
    @State private var savedFallbackURL: String
    @State private var saveError = false

    init(instanceID: UUID, fallbackURL: String?) {
        self.instanceID = instanceID
        self.fallbackURL = fallbackURL ?? ""
        self.savedFallbackURL = fallbackURL ?? ""
    }

    var body: some View {
        Section {
            HubFallbackURLInput(text: $fallbackURL)
            Button("common.save") {
                do {
                    try instanceManager.updateFallbackURL(for: instanceID, fallbackURL: fallbackURL)
                    fallbackURL = HubURL.normalized(fallbackURL) ?? ""
                    savedFallbackURL = fallbackURL
                    saveError = false
                    WidgetCenter.shared.reloadAllTimelines()
                } catch {
                    saveError = true
                }
            }
            .disabled(!HubURL.isValidFallback(fallbackURL) || HubURL.normalized(fallbackURL) == HubURL.normalized(savedFallbackURL))
            .accessibilityIdentifier("hub.fallback.save")
            if saveError {
                Text("hub.fallback.invalidURL")
                    .foregroundStyle(.red)
            }
        }
    }
}
