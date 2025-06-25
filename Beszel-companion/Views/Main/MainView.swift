import SwiftUI
import Combine

struct MainView: View {
    @StateObject var apiService: BeszelAPIService

    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var dashboardManager: DashboardManager
    @EnvironmentObject var languageManager: LanguageManager
    @ObservedObject var refreshManager: RefreshManager

    var onLogout: () -> Void

    @State private var containerData: [ProcessedContainerData] = []
    @State private var systemDataPoints: [SystemDataPoint] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @Binding var isShowingSettings: Bool

    var body: some View {
        TabView {
            HomeView(
                containerData: containerData,
                systemDataPoints: systemDataPoints,
                isShowingSettings: $isShowingSettings
            )
            .tabItem {
                Label("home.title", systemImage: "house.fill")
            }

            SystemView(
                dataPoints: $systemDataPoints,
                fetchData: fetchData,
                isShowingSettings: $isShowingSettings
            )
            .tabItem {
                Label("system.title", systemImage: "cpu.fill")
            }

            ContainerView(
                processedData: $containerData,
                fetchData: fetchData,
                isShowingSettings: $isShowingSettings
            )
            .tabItem {
                Label("container.title", systemImage: "shippingbox.fill")
            }
        }
        .task { await fetchData() }
        .task {
            refreshManager.adjustTimer(for: settingsManager.selectedTimeRange)
            await fetchData()
        }
        .onChange(of: settingsManager.selectedTimeRange) { _, newTimeRange in
            refreshManager.adjustTimer(for: newTimeRange)
            Task { await fetchData() }
        }
        .onReceive(refreshManager.$refreshSignal) { _ in
            Task {
                await fetchData()
            }
        }
    }

    private func fetchData() async {
        isLoading = true
        errorMessage = nil
        let filter = settingsManager.apiFilterString

        do {
            async let containerRecords = apiService.fetchMonitors(filter: filter)
            async let systemRecords = apiService.fetchSystemStats(filter: filter)

            self.containerData = DataProcessor.transform(records: try await containerRecords)
            self.systemDataPoints = DataProcessor.transformSystem(records: try await systemRecords)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
