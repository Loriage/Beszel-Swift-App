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
                        await store.fetchData()
                        
                        while !Task.isCancelled {
                            let interval = settingsManager.selectedTimeRange.refreshInterval
                            
                            try? await Task.sleep(for: .seconds(interval))
                            if !Task.isCancelled && !isShowingSettings {
                                await store.fetchData()
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
