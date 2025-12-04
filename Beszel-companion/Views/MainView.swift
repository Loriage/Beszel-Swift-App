import SwiftUI

struct MainView: View {
    @State private var store: BeszelStore?
    
    @State private var isShowingSettings = false
    @State private var selectedTab: AppTab = .home
    
    let instance: Instance
    let instanceManager: InstanceManager
    let settingsManager: SettingsManager
    let refreshManager: RefreshManager
    let dashboardManager: DashboardManager
    let languageManager: LanguageManager
    
    var body: some View {
        Group {
            if let store = store {
                TabView(selection: $selectedTab) {
                    Tab(value: .home) {
                        NavigationStack {
                            HomeView()
                                .withMainToolbar(instanceManager: instanceManager, onSettingsTap: { isShowingSettings = true })
                        }
                    } label: {
                        Label("home.title", systemImage: "house.fill")
                    }
                    
                    Tab(value: .system) {
                        NavigationStack {
                            SystemView()
                                .withMainToolbar(instanceManager: instanceManager, onSettingsTap: { isShowingSettings = true })
                        }
                    } label: {
                        Label("system.title", systemImage: "cpu.fill")
                    }
                    
                    Tab(value: .container) {
                        NavigationStack {
                            ContainerView()
                                .withMainToolbar(instanceManager: instanceManager, onSettingsTap: { isShowingSettings = true })
                        }
                    } label: {
                        Label("container.title", systemImage: "shippingbox.fill")
                    }
                }
                .environment(store)
                .sheet(isPresented: $isShowingSettings) {
                    LazyView(SettingsView())
                }
                .task(id: settingsManager.selectedTimeRange) {
                    await store.fetchData()
                }
                .task(id: instanceManager.activeSystem) {
                    store.updateDataForActiveSystem()
                }
                .onChange(of: refreshManager.refreshSignal) {
                    guard !isShowingSettings else { return }
                    Task { await store.fetchData() }
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
    func withMainToolbar(instanceManager: InstanceManager, onSettingsTap: @escaping () -> Void) -> some View {
        self.toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SystemSwitcherView(instanceManager: instanceManager)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onSettingsTap) {
                    Image(systemName: "gearshape.fill")
                }
            }
        }
    }
}
