import SwiftUI

struct MainView: View {
    @State private var dataService: DataService
    @State private var chartDataManager: ChartDataManager
    @State private var homeViewModel: HomeViewModel
    @State private var systemViewModel: SystemViewModel
    @State private var containerViewModel: ContainerViewModel

    let instanceManager: InstanceManager
    @Binding var isShowingSettings: Bool
    @Binding var selectedTab: Tab

    init(instance: Instance, instanceManager: InstanceManager, settingsManager: SettingsManager, refreshManager: RefreshManager, dashboardManager: DashboardManager, languageManager: LanguageManager, isShowingSettings: Binding<Bool>, selectedTab: Binding<Tab>) {
        self.instanceManager = instanceManager
        self._isShowingSettings = isShowingSettings
        self._selectedTab = selectedTab

        let dataService = DataService(
            instance: instance,
            settingsManager: settingsManager,
            instanceManager: instanceManager
        )
        _dataService = State(wrappedValue: dataService)
        
        let chartDataManager = ChartDataManager(
            dataService: dataService,
            settingsManager: settingsManager,
            dashboardManager: dashboardManager,
            instanceManager: instanceManager
        )
        _chartDataManager = State(wrappedValue: chartDataManager)

        _homeViewModel = State(wrappedValue: HomeViewModel(
            chartDataManager: chartDataManager,
            dashboardManager: dashboardManager,
            languageManager: languageManager
        ))
        
        _systemViewModel = State(wrappedValue: SystemViewModel(
            chartDataManager: chartDataManager
        ))

        _containerViewModel = State(wrappedValue: ContainerViewModel(
            chartDataManager: chartDataManager
        ))
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                HomeView(homeViewModel: homeViewModel)
                .tabItem {
                    Label("home.title", systemImage: "house.fill")
                }
                .tag(Tab.home)
                
                SystemView(systemViewModel: systemViewModel)
                .tabItem {
                    Label("system.title", systemImage: "cpu.fill")
                }
                .tag(Tab.system)
                
                ContainerView(viewModel: containerViewModel)
                .tabItem {
                    Label("container.title", systemImage: "shippingbox.fill")
                }
                .tag(Tab.container)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    SystemSwitcherView(instanceManager: instanceManager)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {isShowingSettings = true}) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
        .task {
            // Initial fetch
            await dataService.fetchData()
        }
        .onChange(of: instanceManager.activeSystem) {
            chartDataManager.updateData()
        }
    }
}
