import Foundation
import SwiftUI
import Combine

class DashboardManager: ObservableObject {
    static let shared = DashboardManager()

    @AppStorage("pinnedItemsByInstance", store: .sharedSuite) private var allPinsData: Data = Data()

    @Published var pinnedItems: [PinnedItem] = []

    private var cancellables = Set<AnyCancellable>()

    var allPinsForActiveInstance: [ResolvedPinnedItem] {
        guard let activeInstanceID = InstanceManager.shared.activeInstance?.id.uuidString else {
            return []
        }
        
        let allSystemPins = decodeAllPins()
        
        let resolvedItems = allSystemPins.flatMap { (key, items) -> [ResolvedPinnedItem] in
            let prefix = "\(activeInstanceID)-"

            guard key.hasPrefix(prefix) else {
                return []
            }

            let systemID = String(key.dropFirst(prefix.count))

            return items.map { ResolvedPinnedItem(item: $0, systemID: systemID) }
        }
        
        return Array(Set(resolvedItems))
    }

    init() {
        InstanceManager.shared.$activeSystem
            .sink { [weak self] activeSystem in
                self?.loadPins(
                    for: InstanceManager.shared.activeInstance,
                    system: activeSystem
                )
            }
            .store(in: &cancellables)
    }

    private func compositeKey(for instanceID: String, systemID: String) -> String {
        return "\(instanceID)-\(systemID)"
    }

    private func loadPins(for instance: Instance?, system: SystemRecord?) {
        guard let instanceID = instance?.id.uuidString, let systemID = system?.id else {
            self.pinnedItems = []
            return
        }
        
        let key = compositeKey(for: instanceID, systemID: systemID)
        let allPins = decodeAllPins()
        self.pinnedItems = allPins[key] ?? []
    }

    func isPinned(_ item: PinnedItem, onSystem systemID: String) -> Bool {
        guard let instanceID = InstanceManager.shared.activeInstance?.id.uuidString else {
            return false
        }
        let key = compositeKey(for: instanceID, systemID: systemID)
        let allPins = decodeAllPins()
        return allPins[key]?.contains(item) ?? false
    }

    func isPinned(_ item: PinnedItem) -> Bool {
        pinnedItems.contains(item)
    }

    func togglePin(for item: PinnedItem, onSystem systemID: String) {
        guard let instanceID = InstanceManager.shared.activeInstance?.id.uuidString else { return }
        let key = compositeKey(for: instanceID, systemID: systemID)
        
        var allPins = decodeAllPins()
        var currentPins = allPins[key] ?? []
        
        if let index = currentPins.firstIndex(of: item) {
            currentPins.remove(at: index)
        } else {
            currentPins.append(item)
        }
        
        allPins[key] = currentPins.isEmpty ? nil : currentPins
        saveAllPins(allPins)
        
        if systemID == InstanceManager.shared.activeSystem?.id {
            loadPins(for: InstanceManager.shared.activeInstance, system: InstanceManager.shared.activeSystem)
        } else {
            objectWillChange.send()
        }
    }

    func togglePin(for item: PinnedItem) {
        guard let activeSystemID = InstanceManager.shared.activeSystem?.id else { return }
        togglePin(for: item, onSystem: activeSystemID)
    }

    func removeAllPinsForActiveSystem() {
        guard let instanceID = InstanceManager.shared.activeInstance?.id.uuidString,
              let systemID = InstanceManager.shared.activeSystem?.id else { return }
        let key = compositeKey(for: instanceID, systemID: systemID)
        
        var allPins = decodeAllPins()
        allPins.removeValue(forKey: key)
        saveAllPins(allPins)
        
        self.pinnedItems = []
    }

    func nukeAllPins() {
        allPinsData = Data()
        self.pinnedItems = []
    }

    private func saveAllPins(_ allPins: [String: [PinnedItem]]) {
        if let data = try? JSONEncoder().encode(allPins) {
            allPinsData = data
        }
    }

    private func decodeAllPins() -> [String: [PinnedItem]] {
        if let items = try? JSONDecoder().decode([String: [PinnedItem]].self, from: allPinsData) {
            return items
        }
        return [:]
    }
}
