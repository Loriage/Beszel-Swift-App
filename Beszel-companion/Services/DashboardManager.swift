import Foundation
import SwiftUI
import Combine

class DashboardManager: ObservableObject {
    static let shared = DashboardManager()

    @AppStorage("pinnedItemsByInstance", store: .sharedSuite) private var allPinsData: Data = Data()

    @Published var pinnedItems: [PinnedItem] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        InstanceManager.shared.$activeInstance
            .sink { [weak self] activeInstance in
                self?.loadPins(for: activeInstance)
            }
            .store(in: &cancellables)
    }
    
    private func loadPins(for instance: Instance?) {
        guard let instanceID = instance?.id.uuidString else {
            self.pinnedItems = []
            return
        }
        
        let allPins = decodeAllPins()
        self.pinnedItems = allPins[instanceID] ?? []
    }

    func isPinned(_ item: PinnedItem) -> Bool {
        pinnedItems.contains(item)
    }

    func togglePin(for item: PinnedItem) {
        guard let activeInstanceID = InstanceManager.shared.activeInstance?.id.uuidString else { return }
        
        var allPins = decodeAllPins()
        var currentInstancePins = allPins[activeInstanceID] ?? []
        
        if isPinned(item) {
            currentInstancePins.removeAll { $0 == item }
        } else {
            currentInstancePins.append(item)
        }
        
        allPins[activeInstanceID] = currentInstancePins
        saveAllPins(allPins)
        
        self.pinnedItems = currentInstancePins
    }

    func removeAllPinsForActiveInstance() {
        guard let activeInstanceID = InstanceManager.shared.activeInstance?.id.uuidString else { return }
        
        var allPins = decodeAllPins()
        allPins.removeValue(forKey: activeInstanceID)
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
