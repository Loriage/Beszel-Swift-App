import Foundation
import Combine
import SwiftUI

class InstanceManager: ObservableObject {
    static let shared = InstanceManager()
    static let appGroupIdentifier = "group.com.nohitdev.Beszel"
    private static var didLogStoreType = false

    // Helper to get the correct UserDefaults instance
    private static func getStore() -> UserDefaults {
        if let store = UserDefaults(suiteName: appGroupIdentifier) {
            if !didLogStoreType {
                print("[InstanceManager] Debug: Utilisation des UserDefaults de l'App Group. La communication avec le widget devrait fonctionner.")
                didLogStoreType = true
            }
            return store
        } else {
            if !didLogStoreType {
                print("[InstanceManager] Debug: App Group indisponible. Utilisation des UserDefaults standards. Ceci est normal pour les builds sideloadées. Le widget ne fonctionnera pas.")
                didLogStoreType = true
            }
            return .standard
        }
    }

    private var userDefaultsStore: UserDefaults {
        return InstanceManager.getStore()
    }

    private var instancesData: Data {
        get { userDefaultsStore.data(forKey: "instances") ?? Data() }
        set { userDefaultsStore.set(newValue, forKey: "instances") }
    }

    var activeInstanceIDString: String? {
        get { userDefaultsStore.string(forKey: "activeInstanceID") }
        set { userDefaultsStore.set(newValue, forKey: "activeInstanceID") }
    }

    var activeSystemIDString: String? {
        get { userDefaultsStore.string(forKey: "activeSystemID") }
        set { userDefaultsStore.set(newValue, forKey: "activeSystemID") }
    }

    @Published var instances: [Instance] = []
    @Published var activeInstance: Instance?
    @Published var systems: [SystemRecord] = []
    @Published var activeSystem: SystemRecord?
    @Published var isLoadingSystems = false

    private let keychainService = "com.nohitdev.Beszel.instances"
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.instances = decodeInstances()
        updateActiveInstance()

        self.$activeInstance
            .removeDuplicates(by: { $0?.id == $1?.id })
            .sink { [weak self] instance in
                guard let self = self else { return }
                if let instance = instance {
                    self.fetchSystemsForInstance(instance)
                } else {
                    self.systems = []
                    self.activeSystem = nil
                }
            }
            .store(in: &cancellables)
    }

    func addInstance(name: String, url: String, email: String, password: String) {
        let newInstance = Instance(id: UUID(), name: name, url: url, email: email)
        savePassword(password: password, forInstanceID: newInstance.id)
        
        instances.append(newInstance)
        saveInstances()

        setActiveInstance(newInstance)
    }

    func deleteInstance(_ instance: Instance) {
        deletePassword(forInstanceID: instance.id)
        instances.removeAll { $0.id == instance.id }
        saveInstances()
        
        if activeInstance?.id == instance.id {
            setActiveInstance(instances.first)
        }
    }

    func setActiveInstance(_ instance: Instance?) {
        if activeInstanceIDString != instance?.id.uuidString {
            activeSystemIDString = nil
            activeSystem = nil
            systems = []
        }
        self.activeInstanceIDString = instance?.id.uuidString
        updateActiveInstance()
    }

    private func fetchSystemsForInstance(_ instance: Instance) {
        Task {
            await MainActor.run { self.isLoadingSystems = true }
            
            let password = self.loadPassword(for: instance) ?? ""
            let apiService = BeszelAPIService(url: instance.url, email: instance.email, password: password)
            
            do {
                let fetchedSystems = try await apiService.fetchSystems()
                await MainActor.run {
                    self.systems = fetchedSystems.sorted(by: { $0.name < $1.name })
                    self.updateActiveSystem()
                    self.isLoadingSystems = false
                }
            } catch {
                print("Failed to fetch systems: \(error)")
                await MainActor.run {
                    self.systems = []
                    self.activeSystem = nil
                    self.isLoadingSystems = false
                }
            }
        }
    }

    var activeSystemSelection: Binding<String?> {
        Binding<String?>(
            get: { self.activeSystemIDString },
            set: { newID in
                self.activeSystemIDString = newID
                self.updateActiveSystem()
            }
        )
    }
    
    func loadPassword(for instance: Instance) -> String? {
        guard let passwordData = KeychainHelper.load(service: keychainService, account: instance.id.uuidString) else {
            return nil
        }
        return String(data: passwordData, encoding: .utf8)
    }
    
    func logoutAll() {
        for instance in instances {
            deletePassword(forInstanceID: instance.id)
        }
        instances.removeAll()
        saveInstances()
        setActiveInstance(nil)
        
        DashboardManager.shared.nukeAllPins()
    }
    
    var activeInstanceSelection: Binding<String?> {
        Binding<String?>(
            get: {
                self.activeInstanceIDString
            },
            set: { newID in
                self.activeInstanceIDString = newID
                self.updateActiveInstance()
            }
        )
    }

    private func updateActiveInstance() {
        guard let activeIDString = self.activeInstanceIDString,
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
        
        if let activeID = self.activeSystemIDString, let system = systems.first(where: { $0.id == activeID }) {
            self.activeSystem = system
        } else {
            self.activeSystem = systems.first
            self.activeSystemIDString = systems.first?.id
        }
    }

    private func saveInstances() {
        if let data = try? JSONEncoder().encode(instances) {
            instancesData = data
        }
    }

    private func decodeInstances() -> [Instance] {
        guard let decodedInstances = try? JSONDecoder().decode([Instance].self, from: instancesData), !decodedInstances.isEmpty else {
            return []
        }
        return decodedInstances
    }
    
    private func savePassword(password: String, forInstanceID instanceID: UUID) {
        if let passwordData = password.data(using: .utf8) {
            KeychainHelper.save(data: passwordData, service: keychainService, account: instanceID.uuidString)
        }
    }

    private func deletePassword(forInstanceID instanceID: UUID) {
        KeychainHelper.delete(service: keychainService, account: instanceID.uuidString)
    }
}
