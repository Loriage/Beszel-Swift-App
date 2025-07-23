import SwiftUI

enum Tab {
    case home
    case system
    case container
}

struct MainView: View {
    @StateObject private var dataService: DataService
    @StateObject private var chartDataManager: ChartDataManager
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var systemViewModel: SystemViewModel
    @StateObject private var containerViewModel: ContainerViewModel

    @ObservedObject var instanceManager: InstanceManager
    @Binding var isShowingSettings: Bool
    @Binding var selectedTab: Tab

    init(instance: Instance, instanceManager: InstanceManager, settingsManager: SettingsManager, refreshManager: RefreshManager, dashboardManager: DashboardManager, isShowingSettings: Binding<Bool>, selectedTab: Binding<Tab>) {
        self.instanceManager = instanceManager
        self._isShowingSettings = isShowingSettings
        self._selectedTab = selectedTab

        let dataService = DataService(
            instance: instance,
            settingsManager: settingsManager,
            refreshManager: refreshManager,
            instanceManager: instanceManager
        )
        _dataService = StateObject(wrappedValue: dataService)
        
        let chartDataManager = ChartDataManager(
            dataService: dataService,
            settingsManager: settingsManager,
            dashboardManager: dashboardManager,
            instanceManager: instanceManager
        )
        _chartDataManager = StateObject(wrappedValue: chartDataManager)

        _homeViewModel = StateObject(wrappedValue: HomeViewModel(
            chartDataManager: chartDataManager,
            dashboardManager: dashboardManager
        ))
        
        _systemViewModel = StateObject(wrappedValue: SystemViewModel(
            chartDataManager: chartDataManager
        ))

        _containerViewModel = StateObject(wrappedValue: ContainerViewModel(
            chartDataManager: chartDataManager
        ))
    }

    private var activeContainerDataBinding: Binding<[ProcessedContainerData]> {
        Binding<[ProcessedContainerData]>(
            get: {
                guard let activeSystemID = instanceManager.activeSystem?.id else { return [] }
                return dataService.containerDataBySystem[activeSystemID] ?? []
            },
            set: { newValue in
                guard let activeSystemID = instanceManager.activeSystem?.id else { return }
                dataService.containerDataBySystem[activeSystemID] = newValue
            }
        )
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                HomeView(
                    homeViewModel: homeViewModel
                )
                .tabItem {
                    Label("home.title", systemImage: "house.fill")
                }
                .tag(Tab.home)
                
                SystemView(
                    systemViewModel: systemViewModel
                )
                .tabItem {
                    Label("system.title", systemImage: "cpu.fill")
                }
                .tag(Tab.system)
                
                ContainerView(
                    viewModel: containerViewModel
                )
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
    }
}
