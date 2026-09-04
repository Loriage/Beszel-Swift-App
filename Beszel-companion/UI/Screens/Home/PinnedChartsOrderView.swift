import SwiftUI

struct PinnedChartsOrderView: View {
    @Environment(DashboardManager.self) private var dashboardManager
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.dismiss) private var dismiss

    let instanceID: String
    let systemNames: [String: String]

    var body: some View {
        let pins = dashboardManager[layoutFor: instanceID].sortedPins(
            dashboardManager.pins(forInstanceID: instanceID),
            systemNames: systemNames,
            bundle: languageManager.currentBundle
        )
        NavigationStack {
            List {
                Section {
                    ForEach(pins) { pin in
                        PinnedChartOrderRow(
                            title: pin.item.localizedDisplayName(for: languageManager.currentBundle),
                            systemName: systemNames[pin.systemID] ?? pin.systemID
                        )
                        .accessibilityIdentifier("pinned-order-\(pin.id)")
                    }
                    .onMove { source, destination in
                        dashboardManager.movePins(
                            fromOffsets: source, toOffset: destination,
                            in: pins, forInstanceID: instanceID
                        )
                    }
                } footer: {
                    Text("dashboard.reorder.footer")
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .accessibilityIdentifier("pinned-chart-order-list")
            .navigationTitle("dashboard.reorder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("dashboard.reorder.done") { dismiss() }
                        .accessibilityIdentifier("pinned-chart-order-done")
                }
            }
        }
    }
}

private struct PinnedChartOrderRow: View {
    let title: String
    let systemName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Text(systemName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
