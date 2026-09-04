import SwiftUI

struct MainView: View {
    @State private var store: BeszelStore?

    @State private var isShowingSettings = false
    @State private var selectedTab: AppTab = .home
    @State private var containerNavigationPath = NavigationPath()

    let instance: Instance
    let instanceManager: InstanceManager
    let settingsManager: SettingsManager
    let dashboardManager: DashboardManager
    let languageManager: LanguageManager
    let alertManager: AlertManager
    
    var body: some View {
        Group {
            if let store = store {
                TabView(selection: $selectedTab) {
                    Tab(value: .home) {
                        NavigationStack {
                            HomeView {
                                isShowingSettings = true
                            }
                        }
                    } label: {
                        Label("home.title", systemImage: "house.fill")
                    }

                    Tab(value: .system) {
                        NavigationStack {
                            SystemView()
                                .withMainToolbar(instanceManager: instanceManager, showsSystemSwitcher: true) {
                                    isShowingSettings = true
                                }
                        }
                    } label: {
                        Label("system.title", systemImage: "cpu.fill")
                    }

                    Tab(value: .container) {
                        NavigationStack(path: $containerNavigationPath) {
                            ContainerView()
                                .withMainToolbar(instanceManager: instanceManager, showsSystemSwitcher: true) {
                                    isShowingSettings = true
                                }
                                .navigationDestination(for: ProcessedContainerData.self) { container in
                                    ContainerDetailView(container: container)
                                        .environment(store)
                                        .environment(\.chartXDomain, store.xDomain)
                                        .environment(\.chartShowXGridLines, settingsManager.showChartGridLines)
                                }
                        }
                    } label: {
                        Label("container.title", systemImage: "shippingbox.fill")
                    }

                    Tab(value: .alerts) {
                        NavigationStack {
                            AlertsTabView()
                                .withMainToolbar(instanceManager: instanceManager, showsSystemSwitcher: false) {
                                    isShowingSettings = true
                                }
                        }
                    } label: {
                        Label("alerts.title", systemImage: "bell.fill")
                    }
                    .badge(alertManager.badgeCount)
                }
                .environment(store)
                .environment(\.chartXDomain, store.xDomain)
                .environment(\.chartShowXGridLines, settingsManager.showChartGridLines)
                .task(id: settingsManager.selectedTimeRange) {
                    await runRefreshLoop(store: store)
                }
                .task(id: instanceManager.activeSystem) {
                    containerNavigationPath = NavigationPath()
                    store.updateDataForActiveSystem()
                }
                .sheet(isPresented: $isShowingSettings) {
                    LazyView(SettingsView()).environment(store)
                }
                .task(id: alertManager.pendingAlertDetail?.id) {
                    if let pendingDetail = alertManager.pendingAlertDetail {
                        await handleAlertDeepLink(pendingDetail)
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

    private func runRefreshLoop(store: BeszelStore) async {
        await store.fetchData()
        guard !Task.isCancelled else { return }
        await alertManager.fetchAlerts(for: instance, instanceManager: instanceManager)

        var elapsed: TimeInterval = 0
        do {
            while true {
                let fastInterval = settingsManager.selectedTimeRange.fastRefreshInterval
                let refreshInterval = settingsManager.selectedTimeRange.refreshInterval

                try await Task.sleep(for: .seconds(fastInterval))
                try Task.checkCancellation()
                elapsed += fastInterval

                guard !isShowingSettings else { continue }
                if elapsed >= refreshInterval {
                    elapsed = 0
                    await store.fetchData()
                } else {
                    await store.refreshLatestStatsOnly()
                }
                await alertManager.refreshAlertsQuick(for: instance, instanceManager: instanceManager)
            }
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }

    @MainActor
    private func handleAlertDeepLink(_ pendingDetail: AlertDetail) async {
        isShowingSettings = false
        selectedTab = .alerts
        if alertManager.alertHistory.isEmpty {
            await alertManager.fetchAlerts(for: instance, instanceManager: instanceManager)
        }
        alertManager.pendingAlertDetail = nil
    }
}

extension View {
    func withMainToolbar(
        instanceManager: InstanceManager,
        showsSystemSwitcher: Bool,
        canReorder: Bool = false,
        onReorderTap: (() -> Void)? = nil,
        onSettingsTap: @escaping () -> Void
    ) -> some View {
        self.toolbar {
            if showsSystemSwitcher {
                ToolbarItem(placement: .topBarLeading) {
                    SystemSwitcherView(instanceManager: instanceManager)
                }
            }
            MainToolbarActions(
                canReorder: canReorder,
                onReorderTap: onReorderTap,
                onSettingsTap: onSettingsTap
            )
        }
    }
}

extension MainView {
    enum AppTab: String, CaseIterable, Identifiable {
        case home
        case system
        case container
        case alerts

        var id: String { self.rawValue }
    }
}
