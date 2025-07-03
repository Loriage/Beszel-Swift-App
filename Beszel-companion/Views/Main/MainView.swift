import SwiftUI

enum Tab {
    case home
    case system
    case container
}

struct MainView: View {
    @StateObject private var viewModel: MainViewModel

    @ObservedObject var instanceManager: InstanceManager
    @Binding var isShowingSettings: Bool
    @Binding var selectedTab: Tab

    init(instance: Instance, instanceManager: InstanceManager, settingsManager: SettingsManager, refreshManager: RefreshManager, isShowingSettings: Binding<Bool>, selectedTab: Binding<Tab>) {
        self.instanceManager = instanceManager
        self._isShowingSettings = isShowingSettings
        self._selectedTab = selectedTab

        _viewModel = StateObject(wrappedValue: MainViewModel(
            instance: instance,
            settingsManager: settingsManager,
            refreshManager: refreshManager,
            instanceManager: instanceManager
        ))
    }

    var body: some View {
        NavigationView{
            TabView(selection: $selectedTab) {
                HomeView(
                    containerData: viewModel.containerData,
                    systemDataPoints: viewModel.systemDataPoints,
                )
                .tabItem {
                    Label("home.title", systemImage: "house.fill")
                }
                .tag(Tab.home)
                
                SystemView(
                    dataPoints: $viewModel.systemDataPoints,
                    fetchData: { viewModel.fetchData() },
                )
                .tabItem {
                    Label("system.title", systemImage: "cpu.fill")
                }
                .tag(Tab.system)
                
                ContainerView(
                    processedData: $viewModel.containerData,
                    fetchData: { viewModel.fetchData() },
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
