import SwiftUI

struct MainView: View {
    @State private var store: BeszelStore?

    @State private var isShowingSettings = false
    @State private var selectedTab: AppTab = .home

    let instance: Instance
    let instanceManager: InstanceManager
    let settingsManager: SettingsManager
    let dashboardManager: DashboardManager
    let languageManager: LanguageManager
    let alertManager: AlertManager
    
    var body: some View {
        Group {
            if let store = store {
                NavigationStack {
                    TabView(selection: $selectedTab) {
                        Tab(value: .home) {
                            HomeView()
                        } label: {
                            Label("home.title", systemImage: "house.fill")
                        }
                        Tab(value: .system) {
                            SystemView()
                        } label: {
                            Label("system.title", systemImage: "cpu.fill")
                        }
                        Tab(value: .container) {
                            ContainerView()
                        } label: {
                            Label("container.title", systemImage: "shippingbox.fill")
                        }
                    }
                    .environment(store)
                    .toolbar {
                        if selectedTab != .home {
                            ToolbarItem(placement: .topBarLeading) {
                                SystemSwitcherView(instanceManager: instanceManager)
                            }
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: { isShowingSettings = true }) {
                                Image(systemName: "gearshape.fill")
                            }
                        }
                    }
                    .task(id: settingsManager.selectedTimeRange) {
                        // Initial full fetch when view appears or time range changes
                        await store.fetchData()
                        await alertManager.fetchAlerts(for: instance, instanceManager: instanceManager)

                        // Fast polling loop for real-time updates
                        while !Task.isCancelled {
                            let fastInterval = settingsManager.selectedTimeRange.fastRefreshInterval

                            try? await Task.sleep(for: .seconds(fastInterval))
                            if !Task.isCancelled && !isShowingSettings {
                                // Lightweight refresh: latest stats + alerts only
                                await store.refreshLatestStatsOnly()
                                await alertManager.refreshAlertsQuick(for: instance, instanceManager: instanceManager)
                            }
                        }
                    }
                    .task(id: instanceManager.activeSystem) {
                        store.updateDataForActiveSystem()
                    }
                    .sheet(isPresented: $isShowingSettings) {
                        LazyView(SettingsView())
                    }
                    .navigationDestination(for: ProcessedContainerData.self) { container in
                        ContainerDetailView(container: container)
                    }
                }
            } else {
                ProgressView()
                    .task {
                        initializeStore()
                    }
            }
        }
    }
    
    private func initializeStore() {
        let newStore = BeszelStore(
            instance: instance,
            settingsManager: settingsManager,
            dashboardManager: dashboardManager,
            instanceManager: instanceManager
        )
        self.store = newStore
    }
}

extension View {
    func withMainToolbar(instanceManager: InstanceManager, showSystemPicker: Bool = true, onSettingsTap: @escaping () -> Void) -> some View {
        self.toolbar {
            if showSystemPicker {
                ToolbarItem(placement: .topBarLeading) {
                    SystemSwitcherView(instanceManager: instanceManager)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onSettingsTap) {
                    Image(systemName: "gearshape.fill")
                }
            }
        }
    }
}

extension MainView {
    enum AppTab: String, CaseIterable, Identifiable {
        case home
        case system
        case container

        var id: String { self.rawValue }
    }
}
