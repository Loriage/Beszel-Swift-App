import Foundation
import Combine
import SwiftUI

class InstanceManager: ObservableObject {
    static let shared = InstanceManager()
    static let appGroupIdentifier = "group.com.nohitdev.Beszel"

    private let keychainService = "com.nohitdev.Beszel.instances"

    private static func getStore() -> UserDefaults {
        return UserDefaults(suiteName: appGroupIdentifier) ?? .standard
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

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.instances = decodeInstances()
        updateActiveInstance()

        if self.activeInstance == nil, let firstInstance = self.instances.first {
            setActiveInstance(firstInstance)
        }

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
    
    var activeInstanceSelection: Binding<String?> {
        Binding<String?>(
            get: {
                self.activeInstanceIDString
            },
            set: { newID in
                if let newID = newID, let uuid = UUID(uuidString: newID), let instance = self.instances.first(where: { $0.id == uuid }) {
                    self.setActiveInstance(instance)
                } else {
                    self.setActiveInstance(nil)
                }
            }
        )
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

    func fetchSystemsForInstance(_ instance: Instance) {
        Task {
            await MainActor.run { self.isLoadingSystems = true }
            
            let apiService = BeszelAPIService(instance: instance, instanceManager: self)
            
            do {
                let fetchedSystems = try await apiService.fetchSystems()
                await MainActor.run {
                    self.systems = fetchedSystems.sorted(by: { $0.name < $1.name })
                    self.updateActiveSystem()
                    self.isLoadingSystems = false
                }
            } catch {
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Key '\(key)' not found:", context.debugDescription)
                    case .valueNotFound(let value, let context):
                        print("Value '\(value)' not found:", context.debugDescription)
                    case .typeMismatch(let type, let context):
                        print("Type '\(type)' mismatch:", context.debugDescription)
                    case .dataCorrupted(let context):
                        print("Data corrupted:", context.debugDescription)
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }

                await MainActor.run {
                    self.systems = []
                    self.activeSystem = nil
                    self.isLoadingSystems = false
                }
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
        if activeInstanceIDString != instance?.id.uuidString {
            activeSystemIDString = nil
            activeSystem = nil
            systems = []
        }
        self.activeInstanceIDString = instance?.id.uuidString
        updateActiveInstance()
    }

    func loadCredential(for instance: Instance) -> String? {
        if let data = KeychainHelper.load(service: keychainService, account: instance.id.uuidString, useSharedKeychain: true),
           let credential = String(data: data, encoding: .utf8), !credential.isEmpty {
            return credential
        }
        
        if let data = KeychainHelper.load(service: keychainService, account: instance.id.uuidString, useSharedKeychain: false),
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
    
    private func saveCredential(credential: String, for instance: Instance) {
        guard let data = credential.data(using: .utf8) else { return }

        let didSaveToShared = KeychainHelper.save(data: data, service: keychainService, account: instance.id.uuidString, useSharedKeychain: true)
        
        if !didSaveToShared {
            _ = KeychainHelper.save(data: data, service: keychainService, account: instance.id.uuidString, useSharedKeychain: false)
        }
    }

    private func deleteCredential(for instance: Instance) {
        KeychainHelper.delete(service: keychainService, account: instance.id.uuidString, useSharedKeychain: true)
        KeychainHelper.delete(service: keychainService, account: instance.id.uuidString, useSharedKeychain: false)
    }
}
