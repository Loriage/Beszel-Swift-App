import Foundation
import SwiftUI
import Observation
import os
import Security

private let logger = Logger(subsystem: "com.nohitdev.Beszel", category: "InstanceManager")

nonisolated enum SystemsFetchRetryPolicy {
    static let retryDelays: [Duration] = [
        .milliseconds(350),
        .seconds(1)
    ]

    static func shouldRetry(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }

        switch urlError.code {
        case .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .networkConnectionLost,
             .dnsLookupFailed,
             .notConnectedToInternet,
             .cannotLoadFromNetwork,
             .backgroundSessionWasDisconnected:
            return true
        default:
            return false
        }
    }
}

@Observable
@MainActor
final class InstanceManager {
    static let shared = InstanceManager()
    private let keychainService = Constants.keychainService
    
    private var userDefaultsStore: UserDefaults {
        return .sharedSuite
    }
    
    var instances: [Instance] = []
    var activeInstance: Instance?
    var systems: [SystemRecord] = []
    var activeSystem: SystemRecord?
    var isLoadingSystems = false
    var loadError: Error?
    private(set) var systemsLoadRequestID = UUID()
    
    /// System details keyed by system ID (for Beszel agent 0.18.0+)
    var systemDetails: [String: SystemDetailsRecord] = [:]
    
    var activeInstanceID: String? {
        didSet {
            guard activeInstanceID != oldValue else { return }
            userDefaultsStore.set(activeInstanceID, forKey: "activeInstanceID")
            userDefaultsStore.synchronize()

            activeSystemID = nil
            activeSystem = nil
            systems = []
            systemDetails = [:]

            updateActiveInstance()
            requestSystemsReload()
        }
    }

    var activeSystemID: String? {
        didSet {
            guard activeSystemID != oldValue else { return }
            userDefaultsStore.set(activeSystemID, forKey: "activeSystemID")
            userDefaultsStore.synchronize()
            updateActiveSystem()
        }
    }
    
    init() {
        if let data = userDefaultsStore.data(forKey: "instances") {
            do {
                self.instances = try JSONDecoder().decode([Instance].self, from: data)
                restoreNotificationSecrets()
            } catch {
                logger.error("Failed to decode instances on init: \(error.localizedDescription)")
            }
        }
        
        self.activeInstanceID = userDefaultsStore.string(forKey: "activeInstanceID")
        self.activeSystemID = userDefaultsStore.string(forKey: "activeSystemID")
        
        updateActiveInstance()
        
        if self.activeInstance == nil, let firstInstance = self.instances.first {
            setActiveInstance(firstInstance)
        }

        self.isLoadingSystems = self.activeInstance != nil
    }
    
    func requestSystemsReload() {
        loadError = nil
        isLoadingSystems = activeInstance != nil
        systemsLoadRequestID = UUID()
    }

    func fetchSystemsForInstance(_ instance: Instance) async {
        let requestID = systemsLoadRequestID
        isLoadingSystems = true
        loadError = nil

        defer {
            if activeInstance?.id == instance.id, systemsLoadRequestID == requestID {
                isLoadingSystems = false
            }
        }

        let apiService = BeszelAPIService(instance: instance, instanceManager: self)

        do {
            let (fetchedSystems, fetchedDetails) = try await fetchSystemsWithRetry(using: apiService)
            try Task.checkCancellation()
            guard activeInstance?.id == instance.id, systemsLoadRequestID == requestID else { return }

            systems = fetchedSystems.sorted(by: { $0.name < $1.name })
            systemDetails = Dictionary(
                uniqueKeysWithValues: fetchedDetails.map { ($0.system, $0) }
            )

            updateActiveSystem()
            DashboardManager.shared.refreshPins()
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            guard activeInstance?.id == instance.id, systemsLoadRequestID == requestID else { return }
            logger.error("Error fetching systems: \(error.localizedDescription)")
            loadError = error
            systems = []
            systemDetails = [:]
            activeSystem = nil
            DashboardManager.shared.refreshPins()
        }
    }

    private func fetchSystemsWithRetry(
        using apiService: BeszelAPIService
    ) async throws -> ([SystemRecord], [SystemDetailsRecord]) {
        var retryIndex = 0

        while true {
            do {
                async let systemsTask = apiService.fetchSystems()
                async let detailsTask = apiService.fetchSystemDetails()
                return try await (systemsTask, detailsTask)
            } catch {
                try Task.checkCancellation()

                guard SystemsFetchRetryPolicy.shouldRetry(error),
                      retryIndex < SystemsFetchRetryPolicy.retryDelays.count else {
                    throw error
                }

                let delay = SystemsFetchRetryPolicy.retryDelays[retryIndex]
                retryIndex += 1

                if let urlError = error as? URLError {
                    logger.notice("Transient systems request failed with code \(urlError.errorCode); retrying")
                }

                try await Task.sleep(for: delay)
            }
        }
    }
    
    /// Returns system details for a given system ID.
    /// For agent 0.18.0+, this comes from the system_details endpoint.
    /// For older agents, returns nil (details are in SystemInfo).
    func details(for systemID: String) -> SystemDetailsRecord? {
        systemDetails[systemID]
    }
    
    /// Returns the CPU model for a system, checking both new details endpoint and legacy info field.
    func cpuModel(for system: SystemRecord) -> String? {
        // First check new details endpoint (0.18.0+)
        if let details = systemDetails[system.id], let cpu = details.cpu {
            return cpu
        }
        // Fall back to legacy info field (0.17.0 and earlier)
        return system.info?.m
    }
    
    /// Returns the number of CPU cores for a system, checking both sources.
    func cpuCores(for system: SystemRecord) -> Int? {
        if let details = systemDetails[system.id], let cores = details.cores {
            return cores
        }
        return system.info?.c
    }
    
    /// Returns the number of CPU threads for a system.
    func cpuThreads(for system: SystemRecord) -> Int? {
        if let details = systemDetails[system.id], let threads = details.threads {
            return threads
        }
        return system.info?.t
    }
    
    /// Returns the hostname for a system.
    func hostname(for system: SystemRecord) -> String? {
        if let details = systemDetails[system.id], let hostname = details.hostname {
            return hostname
        }
        return system.info?.h
    }
    
    /// Returns the kernel version for a system.
    func kernel(for system: SystemRecord) -> String? {
        if let details = systemDetails[system.id], let kernel = details.kernel {
            return kernel
        }
        return system.info?.k
    }
    
    /// Returns the OS type for a system.
    func osType(for system: SystemRecord) -> Int? {
        if let details = systemDetails[system.id], let os = details.os {
            return os
        }
        return system.info?.os
    }
    
    /// Returns the OS name for a system (only available in 0.18.0+).
    func osName(for system: SystemRecord) -> String? {
        systemDetails[system.id]?.osName
    }
    
    func reloadFromStore() {
        guard let data = userDefaultsStore.data(forKey: "instances") else {
            logger.warning("No instances data found in UserDefaults")
            return
        }

        do {
            let decoded = try JSONDecoder().decode([Instance].self, from: data)
            self.instances = decoded
            restoreNotificationSecrets()
            logger.info("Reloaded \(decoded.count) instances from store")
        } catch {
            logger.error("Failed to decode instances: \(error.localizedDescription)")
        }
    }
    
    func refreshActiveSystem() {
        updateActiveSystem()
    }
    
    func addInstance(name: String, url: String, email: String, password: String, clientCert: ClientCertificatePayload? = nil, caCert: ServerCACertificatePayload? = nil, customHeaders: [String: String] = [:], fallbackURL: String? = nil) {
        let newInstance = Instance(id: UUID(), name: name, url: url, email: email, fallbackURL: HubURL.normalized(fallbackURL), notifyWorkerURL: nil, notifyWebhookSecret: nil)
        saveCredential(credential: password, for: newInstance)
        if let cert = clientCert {
            try? ClientCertificateManager.store(p12Data: cert.p12Data, password: cert.password, for: newInstance.id)
        }
        if let caCert {
            try? ServerCACertificateManager.store(payload: caCert, for: newInstance.id)
        }
        if !customHeaders.isEmpty {
            CustomHeadersManager.store(customHeaders, for: newInstance.id)
        }
        instances.append(newInstance)
        saveInstances()
        setActiveInstance(newInstance)
    }
    
    func updateCredential(for instance: Instance, newCredential: String) {
        saveCredential(credential: newCredential, for: instance)
    }
    
    func updateInstance(_ instance: Instance, name: String, url: String, email: String, password: String, fallbackURL: String?) {
        guard let index = instances.firstIndex(where: { $0.id == instance.id }) else { return }
        let updatedInstance = Instance(
            id: instance.id,
            name: name,
            url: url,
            email: email,
            fallbackURL: HubURL.normalized(fallbackURL),
            notifyWorkerURL: instance.notifyWorkerURL,
            notifyWebhookSecret: instance.notifyWebhookSecret
        )
        instances[index] = updatedInstance
        saveCredential(credential: password, for: updatedInstance)
        saveInstances()
        updateActiveInstance()

        if activeInstance?.id == instance.id {
            requestSystemsReload()
        }
    }

    func updateFallbackURL(for instanceID: UUID, fallbackURL: String?) throws {
        let normalized = HubURL.normalized(fallbackURL)
        guard normalized.map({ HubURL.baseURL($0) != nil }) ?? true else { throw URLError(.badURL) }
        guard let index = instances.firstIndex(where: { $0.id == instanceID }) else { return }
        // Update the current stored value, preserving credentials, notification
        // settings, and any other edits made while the settings sheet was open.
        instances[index].fallbackURL = normalized
        saveInstances()
        updateActiveInstance()
        if activeInstance?.id == instanceID { requestSystemsReload() }
    }

    func updateInstanceNotificationSettings(_ instance: Instance, workerURL: String, webhookSecret: String) {
        guard let index = instances.firstIndex(where: { $0.id == instance.id }) else { return }
        let normalizedSecret = webhookSecret.isEmpty ? nil : webhookSecret
        if let normalizedSecret {
            _ = NotificationSecretManager.store(normalizedSecret, for: instance.id)
        } else {
            NotificationSecretManager.delete(for: instance.id)
        }
        let updatedInstance = Instance(
            id: instance.id,
            name: instance.name,
            url: instance.url,
            email: instance.email,
            fallbackURL: instances[index].fallbackURL,
            notifyWorkerURL: workerURL.isEmpty ? nil : workerURL,
            notifyWebhookSecret: normalizedSecret
        )
        instances[index] = updatedInstance
        saveInstances()
        updateActiveInstance()
    }

    func deleteInstance(_ instance: Instance) {
        deleteSensitiveData(for: instance)
        instances.removeAll { $0.id == instance.id }
        saveInstances()

        if activeInstance?.id == instance.id {
            setActiveInstance(instances.first)
        }
    }
    
    func setActiveInstance(_ instance: Instance?) {
        self.activeInstanceID = instance?.id.uuidString
    }
    
    nonisolated func loadCredential(for instance: Instance) -> String? {
        let service = Constants.keychainService
        if let data = KeychainHelper.load(service: service, account: instance.id.uuidString, useSharedKeychain: true),
           let credential = String(data: data, encoding: .utf8), !credential.isEmpty {
            return credential
        }
        
        if let data = KeychainHelper.load(service: service, account: instance.id.uuidString, useSharedKeychain: false),
           let credential = String(data: data, encoding: .utf8), !credential.isEmpty {
            return credential
        }
        
        return nil
    }
    
    func logoutAll() {
        for instance in instances {
            deleteSensitiveData(for: instance)
        }
        instances.removeAll()
        saveInstances()
        setActiveInstance(nil)
    }
    
    private func updateActiveInstance() {
        guard let activeIDString = self.activeInstanceID,
              let uuid = UUID(uuidString: activeIDString) else {
            self.activeInstance = nil
            return
        }
        self.activeInstance = instances.first { $0.id == uuid }
    }
    
    private func updateActiveSystem() {
        guard !systems.isEmpty else {
            self.activeSystem = nil
            return
        }
        
        if let activeID = self.activeSystemID, let system = systems.first(where: { $0.id == activeID }) {
            self.activeSystem = system
        } else {
            self.activeSystem = systems.first
            self.activeSystemID = systems.first?.id
        }
    }
    
    private func saveInstances() {
        do {
            let data = try JSONEncoder().encode(instances)
            userDefaultsStore.set(data, forKey: "instances")
            userDefaultsStore.synchronize()
        } catch {
            logger.error("Failed to encode instances: \(error.localizedDescription)")
        }
    }

    private func restoreNotificationSecrets() {
        var migratedLegacySecret = false

        for index in instances.indices {
            let instanceID = instances[index].id
            if let legacySecret = instances[index].notifyWebhookSecret, !legacySecret.isEmpty {
                _ = NotificationSecretManager.store(legacySecret, for: instanceID)
                migratedLegacySecret = true
            }
            instances[index].notifyWebhookSecret = NotificationSecretManager.load(for: instanceID)
        }

        if migratedLegacySecret {
            saveInstances()
        }
    }

    private func deleteSensitiveData(for instance: Instance) {
        deleteCredential(for: instance)
        BeszelAPIService.clearCachedAuthentication(for: instance.id)
        NotificationSecretManager.delete(for: instance.id)
        ClientCertificateManager.delete(for: instance.id)
        ServerCACertificateManager.delete(for: instance.id)
        CustomHeadersManager.delete(for: instance.id)
    }
    
    private func saveCredential(credential: String, for instance: Instance) {
        guard let data = credential.data(using: .utf8) else { return }
        let service = keychainService
        
        let didSaveToShared = KeychainHelper.save(data: data, service: service, account: instance.id.uuidString, useSharedKeychain: true)
        
        if !didSaveToShared {
            _ = KeychainHelper.save(data: data, service: service, account: instance.id.uuidString, useSharedKeychain: false)
        }
    }
    
    private func deleteCredential(for instance: Instance) {
        let service = keychainService
        KeychainHelper.delete(service: service, account: instance.id.uuidString, useSharedKeychain: true)
        KeychainHelper.delete(service: service, account: instance.id.uuidString, useSharedKeychain: false)
    }
}
