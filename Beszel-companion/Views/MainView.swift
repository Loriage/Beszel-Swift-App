import SwiftUI

enum Tab {
    case home
    case system
    case container
}

struct MainView: View {
    @StateObject private var viewModel: MainViewModel
    @StateObject private var homeViewModel: HomeViewModel

    @ObservedObject var instanceManager: InstanceManager
    @Binding var isShowingSettings: Bool
    @Binding var selectedTab: Tab

    init(instance: Instance, instanceManager: InstanceManager, settingsManager: SettingsManager, refreshManager: RefreshManager, dashboardManager: DashboardManager, isShowingSettings: Binding<Bool>, selectedTab: Binding<Tab>) {
        self.instanceManager = instanceManager
        self._isShowingSettings = isShowingSettings
        self._selectedTab = selectedTab

        let mainViewModel = MainViewModel(
            instance: instance,
            settingsManager: settingsManager,
            refreshManager: refreshManager,
            instanceManager: instanceManager
        )
        _viewModel = StateObject(wrappedValue: mainViewModel)
        
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(
            dashboardManager: dashboardManager,
            settingsManager: settingsManager,
            instanceManager: instanceManager,
            mainViewModel: mainViewModel
        ))
    }

    private var activeSystemDataPointsBinding: Binding<[SystemDataPoint]> {
        Binding<[SystemDataPoint]>(
            get: {
                guard let activeSystemID = instanceManager.activeSystem?.id else { return [] }
                return viewModel.systemDataPointsBySystem[activeSystemID] ?? []
            },
            set: { newValue in
                guard let activeSystemID = instanceManager.activeSystem?.id else { return }
                viewModel.systemDataPointsBySystem[activeSystemID] = newValue
            }
        )
    }

    private var activeContainerDataBinding: Binding<[ProcessedContainerData]> {
        Binding<[ProcessedContainerData]>(
            get: {
                guard let activeSystemID = instanceManager.activeSystem?.id else { return [] }
                return viewModel.containerDataBySystem[activeSystemID] ?? []
            },
            set: { newValue in
                guard let activeSystemID = instanceManager.activeSystem?.id else { return }
                viewModel.containerDataBySystem[activeSystemID] = newValue
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
                    dataPoints: activeSystemDataPointsBinding,
                    fetchData: { viewModel.fetchData() }
                )
                .tabItem {
                    Label("system.title", systemImage: "cpu.fill")
                }
                .tag(Tab.system)
                
                ContainerView(
                    processedData: activeContainerDataBinding,
                    fetchData: { viewModel.fetchData() }
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
