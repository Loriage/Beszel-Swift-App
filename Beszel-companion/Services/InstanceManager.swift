import Foundation
import Combine
import SwiftUI

class InstanceManager: ObservableObject {
    static let shared = InstanceManager()
    static let appGroupIdentifier = "group.com.nohitdev.Beszel"

    @AppStorage("instances", store: UserDefaults(suiteName: appGroupIdentifier)) private var instancesData: Data = Data()
    @AppStorage("activeInstanceID", store: UserDefaults(suiteName: appGroupIdentifier)) var activeInstanceIDString: String?

    @Published var instances: [Instance] = []
    @Published var activeInstance: Instance?

    private let keychainService = "com.nohitdev.Beszel.instances"

    init() {
        self.instances = decodeInstances()
        updateActiveInstance()
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
        self.activeInstanceIDString = instance?.id.uuidString
        updateActiveInstance()
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
