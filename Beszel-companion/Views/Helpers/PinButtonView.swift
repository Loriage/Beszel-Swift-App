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
