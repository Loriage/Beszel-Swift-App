import Foundation
import SwiftUI
import Observation
import os

private let logger = Logger(subsystem: "com.nohitdev.Beszel", category: "DashboardManager")

@Observable
@MainActor
final class DashboardManager {
    static let shared = DashboardManager()
    
    var allPins: [String: [PinnedItem]] = [:] {
        didSet {
            saveAllPins()
        }
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
        
        let resolvedItems = allPins.flatMap { (key, items) -> [ResolvedPinnedItem] in
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
        self.allPins = decodeAllPins()
    }
    
    func refreshPins() {
        self.allPins = decodeAllPins()
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
    }
    
    private func saveAllPins() {
        do {
            let data = try JSONEncoder().encode(allPins)
            UserDefaults.sharedSuite.set(data, forKey: "pinnedItemsByInstance")
        } catch {
            logger.error("Failed to encode pinned items: \(error.localizedDescription)")
        }
    }

    private func decodeAllPins() -> [String: [PinnedItem]] {
        guard let data = UserDefaults.sharedSuite.data(forKey: "pinnedItemsByInstance") else {
            return [:]
        }
        do {
            return try JSONDecoder().decode([String: [PinnedItem]].self, from: data)
        } catch {
            logger.error("Failed to decode pinned items: \(error.localizedDescription)")
            return [:]
        }
    }
}
