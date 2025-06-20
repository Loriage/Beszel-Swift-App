//
//  PinButtonView.swift
//  Beszel-companion
//
//  Created by Bruno DURAND on 21/06/2025.
//


// Fichier: Views/Helpers/PinButtonView.swift
import SwiftUI

struct PinButtonView: View {
    @EnvironmentObject var dashboardManager: DashboardManager
    let item: PinnedItem

    var body: some View {
        Button(action: {
            dashboardManager.togglePin(for: item)
        }) {
            Image(systemName: dashboardManager.isPinned(item) ? "pin.fill" : "pin")
        }
        .buttonStyle(.plain)
    }
}
