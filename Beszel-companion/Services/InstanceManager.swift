import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class InstanceManager {
    static let shared = InstanceManager()
    static let appGroupIdentifier = "group.com.nohitdev.Beszel"
    
    private let keychainService = "com.nohitdev.Beszel.instances"
    
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
    
    var activeInstanceID: String? {
        didSet {
            guard activeInstanceID != oldValue else { return }
            userDefaultsStore.set(activeInstanceID, forKey: "activeInstanceID")
            
            if activeInstanceID != oldValue {
                activeSystemID = nil
                activeSystem = nil
                systems = []
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
        Task {
            self.isLoadingSystems = true
            
            let apiService = BeszelAPIService(instance: instance, instanceManager: self)
            
            do {
                let fetchedSystems = try await apiService.fetchSystems()
                self.systems = fetchedSystems.sorted(by: { $0.name < $1.name })
                self.updateActiveSystem()
                self.isLoadingSystems = false
                DashboardManager.shared.refreshPins()
            } catch {
                print("Error fetching systems: \(error)")
                self.systems = []
                self.activeSystem = nil
                self.isLoadingSystems = false
                DashboardManager.shared.refreshPins()
            }
        }
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
