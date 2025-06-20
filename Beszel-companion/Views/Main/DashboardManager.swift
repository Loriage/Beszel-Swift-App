//
//  DashboardManager.swift
//  Beszel-companion
//
//  Created by Bruno DURAND on 21/06/2025.
//

import Foundation
import SwiftUI
import Combine

class DashboardManager: ObservableObject {
    @AppStorage("pinnedItems") private var pinnedItemsData: Data = Data()

    @Published var pinnedItems: [PinnedItem] = []

    init() {
        self.pinnedItems = decodeItems()
    }

    func isPinned(_ item: PinnedItem) -> Bool {
        pinnedItems.contains(item)
    }

    func togglePin(for item: PinnedItem) {
        if isPinned(item) {
            pinnedItems.removeAll { $0 == item }
        } else {
            pinnedItems.append(item)
        }
        saveItems()
    }

    private func saveItems() {
        if let data = try? JSONEncoder().encode(pinnedItems) {
            pinnedItemsData = data
        }
    }

    private func decodeItems() -> [PinnedItem] {
        if let items = try? JSONDecoder().decode([PinnedItem].self, from: pinnedItemsData) {
            return items
        }
        return []
    }

    func removeAllPins() {
        pinnedItems.removeAll()
        saveItems()
    }
}
