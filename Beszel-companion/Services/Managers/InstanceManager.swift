import Foundation
import SwiftUI
import Observation
import os

private let logger = Logger(subsystem: "com.nohitdev.Beszel", category: "InstanceManager")

@Observable
@MainActor
final class InstanceManager {
    static let shared = InstanceManager()
    static let appGroupIdentifier = Constants.appGroupId
    
    private let keychainService = Constants.keychainService
    
    private static func getStore() -> UserDefaults {
        return UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
    
    private var userDefaultsStore: UserDefaults {
        return InstanceManager.getStore()
    }
    
    var instances: [Instance] = []
    var activeInstance: Instance?
    var systems: [SystemRecord] = []
    var activeSystem: SystemRecord?
    var isLoadingSystems = false

    /// System details keyed by system ID (for Beszel agent 0.18.0+)
    var systemDetails: [String: SystemDetailsRecord] = [:]
    
    var activeInstanceID: String? {
        didSet {
            guard activeInstanceID != oldValue else { return }
            userDefaultsStore.set(activeInstanceID, forKey: "activeInstanceID")
            
            if activeInstanceID != oldValue {
                activeSystemID = nil
                activeSystem = nil
                systems = []
                systemDetails = [:]
            }
            
            updateActiveInstance()
            
            if let instance = activeInstance {
                fetchSystemsForInstance(instance)
            }
        }
    }
    
    var activeSystemID: String? {
        didSet {
            guard activeSystemID != oldValue else { return }
            userDefaultsStore.set(activeSystemID, forKey: "activeSystemID")
            updateActiveSystem()
        }
    }
    
    init() {
        if let data = userDefaultsStore.data(forKey: "instances"),
           let decoded = try? JSONDecoder().decode([Instance].self, from: data) {
            self.instances = decoded
        }
        
        self.activeInstanceID = userDefaultsStore.string(forKey: "activeInstanceID")
        self.activeSystemID = userDefaultsStore.string(forKey: "activeSystemID")
        
        updateActiveInstance()
        
        if self.activeInstance == nil, let firstInstance = self.instances.first {
            setActiveInstance(firstInstance)
        } else if let instance = self.activeInstance {
            fetchSystemsForInstance(instance)
        }
    }
    
    func fetchSystemsForInstance(_ instance: Instance) {
        Task { @MainActor in
            self.isLoadingSystems = true

            let apiService = BeszelAPIService(instance: instance, instanceManager: self)

            do {
                // Fetch systems and system details in parallel
                async let systemsTask = apiService.fetchSystems()
                async let detailsTask = apiService.fetchSystemDetails()

                let fetchedSystems = try await systemsTask
                let fetchedDetails = try await detailsTask

                self.systems = fetchedSystems.sorted(by: { $0.name < $1.name })

                // Store details indexed by system ID
                self.systemDetails = Dictionary(
                    uniqueKeysWithValues: fetchedDetails.map { ($0.system, $0) }
                )

                self.updateActiveSystem()
                self.isLoadingSystems = false
                DashboardManager.shared.refreshPins()
            } catch {
                logger.error("Error fetching systems: \(error.localizedDescription)")
                self.systems = []
                self.systemDetails = [:]
                self.activeSystem = nil
                self.isLoadingSystems = false
                DashboardManager.shared.refreshPins()
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
        if let data = userDefaultsStore.data(forKey: "instances"),
           let decoded = try? JSONDecoder().decode([Instance].self, from: data) {
            self.instances = decoded
        }
    }

    /// Ensures activeSystem is set based on current systems list.
    /// Call this after updating systems externally (not through fetchSystemsForInstance).
    func refreshActiveSystem() {
        updateActiveSystem()
    }
    
    func addInstance(name: String, url: String, email: String, password: String) {
        let newInstance = Instance(id: UUID(), name: name, url: url, email: email)
        saveCredential(credential: password, for: newInstance)
        instances.append(newInstance)
        saveInstances()
        setActiveInstance(newInstance)
    }
    
    func updateCredential(for instance: Instance, newCredential: String) {
        saveCredential(credential: newCredential, for: instance)
    }
    
    func deleteInstance(_ instance: Instance) {
        deleteCredential(for: instance)
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
        if let data = KeychainHelper.load(service: "com.nohitdev.Beszel.instances", account: instance.id.uuidString, useSharedKeychain: true),
           let credential = String(data: data, encoding: .utf8), !credential.isEmpty {
            return credential
        }
        
        if let data = KeychainHelper.load(service: "com.nohitdev.Beszel.instances", account: instance.id.uuidString, useSharedKeychain: false),
           let credential = String(data: data, encoding: .utf8), !credential.isEmpty {
            return credential
        }
        
        return nil
    }
    
    func logoutAll() {
        for instance in instances {
            deleteCredential(for: instance)
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
        if let data = try? JSONEncoder().encode(instances) {
            userDefaultsStore.set(data, forKey: "instances")
        }
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
