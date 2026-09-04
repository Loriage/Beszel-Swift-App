import SwiftUI

struct MainToolbarActions: ToolbarContent {
    let canReorder: Bool
    let onReorderTap: (() -> Void)?
    let onSettingsTap: () -> Void

    var body: some ToolbarContent {
        // A single native group shares the system's Liquid Glass background.
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let onReorderTap {
                Button(action: onReorderTap) {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .disabled(!canReorder)
                .accessibilityLabel("dashboard.reorder")
                .accessibilityIdentifier("reorder-pinned-charts")
            }

            Button(action: onSettingsTap) {
                Image(systemName: "gearshape.fill")
            }
            .accessibilityLabel("settings.title")
            .accessibilityIdentifier("main-toolbar-settings")
        }
    }
}
