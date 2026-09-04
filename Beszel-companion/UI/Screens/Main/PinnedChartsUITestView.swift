#if DEBUG
import SwiftUI

/// Network-free verification of the real pin controls, ordering sheet, and persisted projection.
/// Summary cards deliberately replace live charts; only this dedicated preferences suite is used.
struct PinnedChartsUITestView: View {
    @Environment(LanguageManager.self) private var languageManager
    @State private var dashboardManager: DashboardManager
    @State private var hubID = "fixture-hub-a"
    @State private var searchText = ""
    @State private var presentedSheet: FixtureSheet?

    private static let preferences: UserDefaults = {
        let suiteName = "com.nohitdev.Beszel.PinOrderUITests"
        guard let preferences = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("The isolated pin-order test suite is unavailable.")
        }
        // A static initializer runs once per process, never as a consequence of view rendering.
        if ProcessInfo.processInfo.arguments.contains("--reset-pin-order-fixture") {
            preferences.removePersistentDomain(forName: suiteName)
        }
        return preferences
    }()

    init() {
        let preferences = Self.preferences
        let manager = DashboardManager(userDefaults: preferences)
        if !preferences.bool(forKey: "fixtureSeeded") {
            let arguments = ProcessInfo.processInfo.arguments
            if !arguments.contains("--pin-order-empty") {
                manager.togglePin(for: .systemCPU, onSystem: "alpha", inInstance: "fixture-hub-a")
                if !arguments.contains("--pin-order-single") {
                    manager.togglePin(for: .systemMemory, onSystem: "alpha", inInstance: "fixture-hub-a")
                    manager.togglePin(for: .systemCPU, onSystem: "beta", inInstance: "fixture-hub-a")
                    manager.togglePin(for: .systemFans, onSystem: "beta", inInstance: "fixture-hub-a")
                }
            }
            manager.togglePin(for: .systemCPU, onSystem: "alpha", inInstance: "fixture-hub-b")
            manager.togglePin(for: .systemDiskUsage, onSystem: "gamma", inInstance: "fixture-hub-b")
            manager.togglePin(for: .systemMemory, onSystem: "gamma", inInstance: "fixture-hub-b")
            preferences.set(true, forKey: "fixtureSeeded")
        }
        dashboardManager = manager
    }

    private var systemNames: [String: String] {
        hubID == "fixture-hub-a" ? ["alpha": "Alpha", "beta": "Beta"]
            : ["alpha": "Alpha", "gamma": "Gamma"]
    }

    var body: some View {
        @Bindable var dashboardManager = dashboardManager
        let names = systemNames
        let bundle = languageManager.currentBundle
        let textSize: DynamicTypeSize = ProcessInfo.processInfo.arguments.contains("--large-text") ? .accessibility3 : .large
        let allPins = dashboardManager[layoutFor: hubID].sortedPins(
            dashboardManager.pins(forInstanceID: hubID), systemNames: names, bundle: bundle
        )
        let visiblePins = allPins.filter { pin in
            searchText.isEmpty
                || (names[pin.systemID] ?? "").localizedCaseInsensitiveContains(searchText)
                || pin.item.localizedDisplayName(for: bundle).localizedCaseInsensitiveContains(searchText)
        }

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Fixture hub", selection: $hubID) {
                        Text(verbatim: "Hub A").tag("fixture-hub-a")
                        Text(verbatim: "Hub B").tag("fixture-hub-b")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("pin-fixture-hub-picker")

                    HomePinnedChartControls(
                        searchText: $searchText,
                        onFilter: { presentedSheet = .filters(hubID) }
                    )

                    if visiblePins.isEmpty {
                        Text(verbatim: "No fixture pins")
                    }
                    ForEach(visiblePins) { pin in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pin.item.localizedDisplayName(for: bundle))
                                .font(.headline)
                            Text(names[pin.systemID] ?? pin.systemID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("pin-fixture-card-\(pin.id)")
                    }
                }
                .padding()
            }
            .navigationTitle("home.title")
            .monitoringNavigationSubtitle("home.subtitle")
            .navigationBarTitleDisplayMode(.large)
            .monitoringScreenBackground()
            .toolbar {
                MainToolbarActions(
                    canReorder: allPins.count > 1,
                    onReorderTap: ProcessInfo.processInfo.arguments.contains("--pin-order-other-tab") ? nil : {
                        // Match Home: snapshot the complete order before presenting, not search results.
                        dashboardManager.setPinOrder(allPins, forInstanceID: hubID)
                        presentedSheet = .reorder(hubID)
                    },
                    onSettingsTap: { presentedSheet = .settings }
                )
            }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .filters(let instanceID):
                    FilterView(layout: $dashboardManager[layoutFor: instanceID])
                        .dynamicTypeSize(textSize)
                case .reorder(let instanceID):
                    PinnedChartsOrderView(instanceID: instanceID, systemNames: names)
                        .dynamicTypeSize(textSize)
                case .settings:
                    PinnedChartsFixtureSettingsView()
                        .dynamicTypeSize(textSize)
                }
            }
        }
        .environment(dashboardManager)
        .environment(languageManager)
        .dynamicTypeSize(textSize)
    }

    private enum FixtureSheet: Identifiable {
        case filters(String)
        case reorder(String)
        case settings

        var id: String {
            switch self {
            case .filters(let instanceID): "filters-\(instanceID)"
            case .reorder(let instanceID): "reorder-\(instanceID)"
            case .settings: "settings"
            }
        }
    }
}

private struct PinnedChartsFixtureSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text(verbatim: "Isolated settings fixture")
                .accessibilityIdentifier("pin-fixture-settings-title")
                .padding()
                .navigationTitle("settings.title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("dashboard.reorder.done") { dismiss() }
                            .accessibilityIdentifier("pin-fixture-settings-done")
                    }
                }
        }
    }
}
#endif
