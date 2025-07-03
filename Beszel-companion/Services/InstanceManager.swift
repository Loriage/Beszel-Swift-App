import Foundation
import Combine
import SwiftUI

class InstanceManager: ObservableObject {
    static let shared = InstanceManager()
    static let appGroupIdentifier = "group.com.nohitdev.Beszel"

    @AppStorage("instances", store: UserDefaults(suiteName: appGroupIdentifier)) private var instancesData: Data = Data()
    @AppStorage("activeInstanceID", store: UserDefaults(suiteName: appGroupIdentifier)) var activeInstanceIDString: String?

    @AppStorage("activeSystemID", store: UserDefaults(suiteName: appGroupIdentifier)) var activeSystemIDString: String?

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
                guard let self = self, let instance = instance else {
                    self?.systems = []
                    self?.activeSystem = nil
                    return
                }
                self.fetchSystemsForInstance(instance)
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
            // Si aucun système n'est sélectionné ou si l'ID stocké n'est plus valide, on prend le premier
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
        guard let data = try? JSONDecoder().decode([Instance].self, from: instancesData) else {
            return []
        }
        return data
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
