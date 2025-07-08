import Foundation
import SwiftUI
import Combine

class DashboardManager: ObservableObject {
    static let shared = DashboardManager()

    @AppStorage("pinnedItemsByInstance", store: .sharedSuite) private var allPinsData: Data = Data()

    @Published var pinnedItems: [PinnedItem] = []

    private var cancellables = Set<AnyCancellable>()

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

    private func compositeKey(for instance: Instance?, system: SystemRecord?) -> String? {
        guard let instanceID = instance?.id.uuidString, let systemID = system?.id else {
            return nil
        }
        return "\(instanceID)-\(systemID)"
    }

    private func loadPins(for instance: Instance?, system: SystemRecord?) {
        guard let key = compositeKey(for: instance, system: system) else {
            self.pinnedItems = []
            return
        }
        
        let allPins = decodeAllPins()
        self.pinnedItems = allPins[key] ?? []
    }

    func isPinned(_ item: PinnedItem) -> Bool {
        pinnedItems.contains(item)
    }

    func togglePin(for item: PinnedItem) {
        guard let key = compositeKey(for: InstanceManager.shared.activeInstance, system: InstanceManager.shared.activeSystem) else { return }
        
        var allPins = decodeAllPins()
        var currentPins = allPins[key] ?? []
        
        if isPinned(item) {
            currentPins.removeAll { $0 == item }
        } else {
            currentPins.append(item)
        }
        
        allPins[key] = currentPins
        saveAllPins(allPins)
        
        self.pinnedItems = currentPins
    }

    func removeAllPinsForActiveSystem() {
        guard let key = compositeKey(for: InstanceManager.shared.activeInstance, system: InstanceManager.shared.activeSystem) else { return }
        
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
