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

    // MARK: - Properties for Bindings
    // Ces propriétés remplacent les anciens Bindings calculés.
    // Elles gèrent la logique métier (mise à jour des UserDefaults, fetch, etc.) dans leurs setters.

    var activeInstanceID: String? {
        didSet {
            guard activeInstanceID != oldValue else { return }
            userDefaultsStore.set(activeInstanceID, forKey: "activeInstanceID")
            
            // Réinitialiser le système si on change d'instance
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
        // Chargement initial
        if let data = userDefaultsStore.data(forKey: "instances"),
           let decoded = try? JSONDecoder().decode([Instance].self, from: data) {
            self.instances = decoded
        }
        
        // Initialisation des IDs depuis le stockage
        self.activeInstanceID = userDefaultsStore.string(forKey: "activeInstanceID")
        self.activeSystemID = userDefaultsStore.string(forKey: "activeSystemID")
        
        updateActiveInstance()

        // Si aucune instance active mais qu'il en existe, on prend la première
        if self.activeInstance == nil, let firstInstance = self.instances.first {
            setActiveInstance(firstInstance)
        } else if let instance = self.activeInstance {
            fetchSystemsForInstance(instance)
        }
    }
    
    // ... (Le reste des méthodes fetchSystems, addInstance, credentials reste identique à la version précédente) ...
    
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
        // Cette méthode met à jour la propriété observable, ce qui déclenchera le didSet
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
        
        // Si un ID est sélectionné et valide, on le garde
        if let activeID = self.activeSystemID, let system = systems.first(where: { $0.id == activeID }) {
            self.activeSystem = system
        } else {
            // Sinon on prend le premier par défaut
            self.activeSystem = systems.first
            // On met à jour l'ID sans déclencher de boucle infinie (le guard au début de didSet protège)
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
