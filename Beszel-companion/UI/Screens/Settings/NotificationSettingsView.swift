import SwiftUI

struct NotificationSettingsView: View {
    @Environment(InstanceManager.self) var instanceManager
    @Environment(AlertManager.self) var alertManager
    @Environment(\.dismiss) var dismiss

    @State private var useCustomWorker = false
    @State private var customWorkerURL: String = ""
    @State private var webhookSecret: String = ""
    @State private var showCopiedToast = false
    @State private var isRegistering = false

    private var currentInstance: Instance? {
        instanceManager.activeInstance
    }

    private var effectiveWorkerURL: String {
        useCustomWorker ? customWorkerURL : Constants.defaultWorkerURL
    }

    var body: some View {
        @Bindable var bindableAlertManager = alertManager

        Form {
            Section {
                Toggle("settings.notifications.enabled", isOn: $bindableAlertManager.notificationsEnabled)
            } header: {
                Text("settings.notifications")
            } footer: {
                Text("settings.notifications.apns.description")
            }

            if alertManager.notificationsEnabled {
                Section {
                    Picker(selection: $useCustomWorker) {
                        Text("settings.notifications.workerType.default").tag(false)
                        Text("settings.notifications.workerType.custom").tag(true)
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.inline)

                    if useCustomWorker {
                        TextField("settings.notifications.workerURL.placeholder", text: $customWorkerURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("settings.notifications.worker")
                } footer: {
                    if useCustomWorker {
                        Text("settings.notifications.workerType.custom.description")
                    } else {
                        Text("settings.notifications.workerType.default.description")
                    }
                }

                Section {
                    if let instance = currentInstance,
                       let workerURL = instance.notifyWorkerURL, !workerURL.isEmpty,
                       let secret = instance.notifyWebhookSecret, !secret.isEmpty {
                        WebhookURLView(workerURL: workerURL, webhookSecret: secret, instanceId: instance.id)
                            .disabled(useCustomWorker && customWorkerURL.isEmpty)
                    } else {
                        HStack {
                            Text("settings.notifications.beszelWebhook.notConfigured")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(.quaternary)
                        }
                    }

                    Button {
                        generateWebhook()
                    } label: {
                        HStack {
                            Text("settings.notifications.generateWebhook")
                            Spacer()
                            if isRegistering {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRegistering || (useCustomWorker && customWorkerURL.isEmpty))
                } header: {
                    Text("settings.notifications.beszelWebhook")
                } footer: {
                    Text("settings.notifications.beszelWebhook.description")
                }


            }
        }
        .navigationTitle("settings.notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadConfiguration()
        }
        .overlay {
            if showCopiedToast {
                VStack {
                    Spacer()
                    Text("common.copied")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: showCopiedToast)
    }

    private func loadConfiguration() {
        if let instance = currentInstance {
            let savedURL = instance.notifyWorkerURL ?? ""
            webhookSecret = instance.notifyWebhookSecret ?? ""

            let trimmedURL = savedURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if trimmedURL.isEmpty || trimmedURL == Constants.defaultWorkerURL {
                useCustomWorker = false
                customWorkerURL = ""
            } else {
                useCustomWorker = true
                customWorkerURL = savedURL
            }
        }
    }

    private func generateWebhook() {
        guard let instance = currentInstance else { return }

        isRegistering = true
        webhookSecret = generateRandomSecret()

        instanceManager.updateInstanceNotificationSettings(
            instance,
            workerURL: effectiveWorkerURL,
            webhookSecret: webhookSecret
        )

        Task {
            let updatedInstance = Instance(
                id: instance.id,
                name: instance.name,
                url: instance.url,
                email: instance.email,
                notifyWorkerURL: effectiveWorkerURL,
                notifyWebhookSecret: webhookSecret
            )
            await PushNotificationService.shared.registerDevice(for: updatedInstance)
            await MainActor.run {
                isRegistering = false
            }
        }
    }

    private func generateRandomSecret() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<32).map { _ in letters.randomElement()! })
    }
}

struct WebhookURLView: View {
    let workerURL: String
    let webhookSecret: String
    let instanceId: UUID
    @State private var webhookURL: String?
    @State private var showCopiedToast = false

    var body: some View {
        HStack {
            if let url = webhookURL {
                Text(url)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                Spacer()

                Button {
                    UIPasteboard.general.string = url
                    showCopiedToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopiedToast = false
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
            } else {
                ProgressView()
            }
        }
        .overlay {
            if showCopiedToast {
                Text("common.copied")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .animation(.easeInOut, value: showCopiedToast)
        .task(id: "\(workerURL)\(webhookSecret)") {
            let instance = Instance(
                id: instanceId,
                name: "",
                url: "",
                email: "",
                notifyWorkerURL: workerURL,
                notifyWebhookSecret: webhookSecret
            )
            webhookURL = await PushNotificationService.shared.generateWebhookURL(for: instance)
        }
    }
}
