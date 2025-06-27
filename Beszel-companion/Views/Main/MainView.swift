import SwiftUI

struct MainView: View {
    @StateObject private var viewModel: MainViewModel

    @ObservedObject var instanceManager: InstanceManager
    @Binding var isShowingSettings: Bool

    init(instance: Instance, instanceManager: InstanceManager, settingsManager: SettingsManager, refreshManager: RefreshManager, isShowingSettings: Binding<Bool>) {
        self.instanceManager = instanceManager
        self._isShowingSettings = isShowingSettings

        _viewModel = StateObject(wrappedValue: MainViewModel(
            instance: instance,
            settingsManager: settingsManager,
            refreshManager: refreshManager
        ))
    }

    var body: some View {
        TabView {
            HomeView(
                containerData: viewModel.containerData,
                systemDataPoints: viewModel.systemDataPoints,
                isShowingSettings: $isShowingSettings,
            )
            .tabItem {
                Label("home.title", systemImage: "house.fill")
            }

            SystemView(
                dataPoints: $viewModel.systemDataPoints,
                fetchData: { viewModel.fetchData() },
                isShowingSettings: $isShowingSettings,
            )
            .tabItem {
                Label("system.title", systemImage: "cpu.fill")
            }

            ContainerView(
                processedData: $viewModel.containerData,
                fetchData: { viewModel.fetchData() },
                isShowingSettings: $isShowingSettings,
            )
            .tabItem {
                Label("container.title", systemImage: "shippingbox.fill")
            }
        }
    }
}
