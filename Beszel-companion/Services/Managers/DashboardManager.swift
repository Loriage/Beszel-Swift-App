import Foundation
import SwiftUI
import Observation
import os

private let logger = Logger(subsystem: "com.nohitdev.Beszel", category: "DashboardManager")

@Observable
@MainActor
final class DashboardManager {
    static let shared = DashboardManager()
    static let layoutsDefaultsKey = "dashboardLayoutsByInstance"

    private let userDefaults: UserDefaults
    
    var allPins: [String: [PinnedItem]] = [:] {
        didSet {
            saveAllPins()
            reconcileLayouts()
        }
    }

    private var layoutsByInstance: [String: DashboardLayout] = [:] {
        didSet { saveLayouts() }
    }

    subscript(layoutFor instanceID: String) -> DashboardLayout {
        get { layoutsByInstance[instanceID] ?? DashboardLayout() }
        set { layoutsByInstance[instanceID] = newValue }
    }
    
    var pinnedItems: [PinnedItem] {
        guard let instanceID = InstanceManager.shared.activeInstance?.id.uuidString,
              let systemID = InstanceManager.shared.activeSystem?.id else {
            return []
        }
        let key = compositeKey(for: instanceID, systemID: systemID)
        return allPins[key] ?? []
    }
    
    var allPinsForActiveInstance: [ResolvedPinnedItem] {
        guard let activeInstanceID = InstanceManager.shared.activeInstance?.id.uuidString else {
            return []
        }
        return pins(forInstanceID: activeInstanceID)
    }
    
    init(userDefaults: UserDefaults = .sharedSuite) {
        self.userDefaults = userDefaults
        self.allPins = decodeAllPins()
        self.layoutsByInstance = decodeLayouts()
    }
    
    func refreshPins() {
        // Read both before publishing either; pin changes also reconcile saved order.
        let pins = decodeAllPins()
        let layouts = decodeLayouts()
        layoutsByInstance = layouts
        allPins = pins
    }

    func pins(forInstanceID instanceID: String) -> [ResolvedPinnedItem] {
        let prefix = "\(instanceID)-"
        var seen: Set<String> = []
        return allPins.keys.sorted().flatMap { key -> [ResolvedPinnedItem] in
            guard key.hasPrefix(prefix) else { return [] }
            let systemID = String(key.dropFirst(prefix.count))
            return (allPins[key] ?? []).compactMap { item in
                let pin = ResolvedPinnedItem(item: item, systemID: systemID)
                return seen.insert(pin.id).inserted ? pin : nil
            }
        }
    }

    func setPinOrder(_ orderedPins: [ResolvedPinnedItem], forInstanceID instanceID: String) {
        let currentPins = pins(forInstanceID: instanceID)
        let availableIDs = Set(currentPins.map(\.id))
        var seen: Set<String> = []
        let orderedIDs = (orderedPins + currentPins).compactMap { pin in
            availableIDs.contains(pin.id) && seen.insert(pin.id).inserted ? pin.id : nil
        }
        var layout = self[layoutFor: instanceID]
        layout.orderedPinIDs = orderedIDs
        layout.sortOption = .custom
        layout.sortDescending = false
        self[layoutFor: instanceID] = layout
    }

    func movePins(
        fromOffsets source: IndexSet,
        toOffset destination: Int,
        in displayedPins: [ResolvedPinnedItem],
        forInstanceID instanceID: String
    ) {
        guard !source.isEmpty,
              source.allSatisfy({ displayedPins.indices.contains($0) }),
              (0...displayedPins.count).contains(destination) else { return }
        var reordered = displayedPins
        reordered.move(fromOffsets: source, toOffset: destination)
        setPinOrder(reordered, forInstanceID: instanceID)
    }
    
    private func compositeKey(for instanceID: String, systemID: String) -> String {
        return "\(instanceID)-\(systemID)"
    }
    
    func isPinned(_ item: PinnedItem, onSystem systemID: String) -> Bool {
        guard let instanceID = InstanceManager.shared.activeInstance?.id.uuidString else {
            return false
        }
        let key = compositeKey(for: instanceID, systemID: systemID)
        return allPins[key]?.contains(item) ?? false
    }
    
    func isPinned(_ item: PinnedItem) -> Bool {
        pinnedItems.contains(item)
    }
    
    func hasPinsForActiveInstance() -> Bool {
        guard let instanceID = InstanceManager.shared.activeInstance?.id.uuidString else {
            return false
        }
        let prefix = "\(instanceID)-"
        return allPins.keys.contains { $0.hasPrefix(prefix) }
    }
    
    func togglePin(for item: PinnedItem, onSystem systemID: String) {
        guard let instanceID = InstanceManager.shared.activeInstance?.id.uuidString else { return }
        togglePin(for: item, onSystem: systemID, inInstance: instanceID)
    }

    func togglePin(for item: PinnedItem, onSystem systemID: String, inInstance instanceID: String) {
        let key = compositeKey(for: instanceID, systemID: systemID)
        
        var currentPins = allPins[key] ?? []
        
        if let index = currentPins.firstIndex(of: item) {
            currentPins.remove(at: index)
        } else {
            currentPins.append(item)
        }
        
        if currentPins.isEmpty {
            allPins.removeValue(forKey: key)
        } else {
            allPins[key] = currentPins
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
        
        allPins.removeValue(forKey: key)
    }
    
    func nukeAllPins() {
        allPins = [:]
        layoutsByInstance = [:]
    }
    
    private func saveAllPins() {
        do {
            let data = try JSONEncoder().encode(allPins)
            userDefaults.set(data, forKey: "pinnedItemsByInstance")
        } catch {
            logger.error("Failed to encode pinned items: \(error.localizedDescription)")
        }
    }

    private func decodeAllPins() -> [String: [PinnedItem]] {
        guard let data = userDefaults.data(forKey: "pinnedItemsByInstance") else {
            return [:]
        }
        do {
            return try JSONDecoder().decode([String: [PinnedItem]].self, from: data)
        } catch {
            logger.error("Failed to decode pinned items: \(error.localizedDescription)")
            return [:]
        }
    }

    private func reconcileLayouts() {
        var layouts = layoutsByInstance
        for (instanceID, var layout) in layouts {
            let currentIDs = pins(forInstanceID: instanceID).map(\.id)
            let availableIDs = Set(currentIDs)
            var seen: Set<String> = []
            layout.orderedPinIDs = (layout.orderedPinIDs + currentIDs).filter {
                availableIDs.contains($0) && seen.insert($0).inserted
            }
            layouts[instanceID] = layout
        }
        if layouts != layoutsByInstance { layoutsByInstance = layouts }
    }

    private func saveLayouts() {
        do {
            let data = try JSONEncoder().encode(layoutsByInstance)
            userDefaults.set(data, forKey: Self.layoutsDefaultsKey)
        } catch {
            logger.error("Failed to encode dashboard layouts")
        }
    }

    private func decodeLayouts() -> [String: DashboardLayout] {
        guard let data = userDefaults.data(forKey: Self.layoutsDefaultsKey) else { return [:] }
        do {
            return try JSONDecoder().decode([String: DashboardLayout].self, from: data)
        } catch {
            logger.error("Failed to decode dashboard layouts")
            return [:]
        }
    }
}
