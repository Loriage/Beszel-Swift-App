import SwiftUI

struct MainView: View {
    @State private var dependencies: AppDependencies?

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
            if let deps = dependencies {
                TabView(selection: $selectedTab) {
                    Tab(value: .home) {
                        NavigationStack {
                            HomeView(homeViewModel: deps.homeViewModel)
                                .withMainToolbar(instanceManager: instanceManager, onSettingsTap: { isShowingSettings = true })
                        }
                    } label: {
                        Label("home.title", systemImage: "house.fill")
                    }

                    Tab(value: .system) {
                        NavigationStack {
                            SystemView(systemViewModel: deps.systemViewModel)
                                .withMainToolbar(instanceManager: instanceManager, onSettingsTap: { isShowingSettings = true })
                        }
                    } label: {
                        Label("system.title", systemImage: "cpu.fill")
                    }

                    Tab(value: .container) {
                        NavigationStack {
                            ContainerView(viewModel: deps.containerViewModel)
                                .withMainToolbar(instanceManager: instanceManager, onSettingsTap: { isShowingSettings = true })
                        }
                    } label: {
                        Label("container.title", systemImage: "shippingbox.fill")
                    }
                }
                .sheet(isPresented: $isShowingSettings) {
                    LazyView(
                        SettingsView(
                            dashboardManager: dashboardManager,
                            settingsManager: settingsManager,
                            languageManager: languageManager,
                            instanceManager: instanceManager
                        )
                    )
                }
                .onChange(of: settingsManager.selectedTimeRange) {
                    Task { await loadData(deps: deps) }
                }
                .onChange(of: refreshManager.refreshSignal) {
                    guard !isShowingSettings else { return }
                    Task { await loadData(deps: deps) }
                }
                .onChange(of: instanceManager.activeSystem) {
                    deps.chartDataManager.updateData()
                }
            } else {
                ProgressView()
                    .task {
                        await initializeServices()
                    }
            }
        }
    }
    
    private func initializeServices() async {
        let ds = DataService(
            instance: instance,
            settingsManager: settingsManager,
            instanceManager: instanceManager
        )
        let cdm = ChartDataManager(
            dataService: ds,
            settingsManager: settingsManager,
            dashboardManager: dashboardManager,
            instanceManager: instanceManager
        )

        let hvm = HomeViewModel(chartDataManager: cdm, dashboardManager: dashboardManager, languageManager: languageManager)
        let svm = SystemViewModel(chartDataManager: cdm)
        let cvm = ContainerViewModel(chartDataManager: cdm)

        await ds.fetchData()
        cdm.updateData()

        self.dependencies = AppDependencies(
            dataService: ds,
            chartDataManager: cdm,
            homeViewModel: hvm,
            systemViewModel: svm,
            containerViewModel: cvm
        )
    }
    
    private func loadData(deps: AppDependencies) async {
        await deps.dataService.fetchData()
        deps.chartDataManager.updateData()
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

@Observable
final class AppDependencies {
    let dataService: DataService
    let chartDataManager: ChartDataManager
    let homeViewModel: HomeViewModel
    let systemViewModel: SystemViewModel
    let containerViewModel: ContainerViewModel
    
    init(
        dataService: DataService,
        chartDataManager: ChartDataManager,
        homeViewModel: HomeViewModel,
        systemViewModel: SystemViewModel,
        containerViewModel: ContainerViewModel
    ) {
        self.dataService = dataService
        self.chartDataManager = chartDataManager
        self.homeViewModel = homeViewModel
        self.systemViewModel = systemViewModel
        self.containerViewModel = containerViewModel
    }
}

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}
