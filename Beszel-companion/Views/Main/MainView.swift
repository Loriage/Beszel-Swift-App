import SwiftUI

struct MainView: View {
    @StateObject var apiService: BeszelAPIService
    @EnvironmentObject var settingsManager: SettingsManager

    var onLogout: () -> Void

    @State private var containerData: [ProcessedContainerData] = []
    @State private var systemDataPoints: [SystemDataPoint] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var isShowingSettings = false

    var body: some View {
        TabView {
            HomeView(
                containerData: containerData,
                systemDataPoints: systemDataPoints,
                onShowSettings: { isShowingSettings = true }
            )
            .tabItem {
                Label("Accueil", systemImage: "house.fill")
            }

            SystemView(
                dataPoints: $systemDataPoints,
                fetchData: fetchData,
                onShowSettings: { isShowingSettings = true }
            )
            .tabItem {
                Label("Système", systemImage: "cpu.fill")
            }

            ContainerView(
                processedData: $containerData,
                fetchData: fetchData,
                onShowSettings: { isShowingSettings = true }
            )
            .tabItem {
                Label("Conteneurs", systemImage: "shippingbox.fill")
            }
        }
        .task { await fetchData() }
        .onChange(of: settingsManager.selectedTimeRange) {
            Task { await fetchData() }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(onLogout: onLogout)
        }
        .task { await fetchData() }
        .onChange(of: settingsManager.selectedTimeRange) {
            Task { await fetchData() }
        }
    }

    private func fetchData() async {
        isLoading = true
        errorMessage = nil
        let filter = settingsManager.apiFilterString

        do {
            async let containerRecords = apiService.fetchMonitors(filter: filter)
            async let systemRecords = apiService.fetchSystemStats(filter: filter)

            self.containerData = transform(records: try await containerRecords)
            self.systemDataPoints = transformSystem(records: try await systemRecords)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func transform(records: [ContainerStatsRecord]) -> [ProcessedContainerData] {
        var containerDict = [String: [StatPoint]]()

        for record in records {
            guard let date = DateFormatter.pocketBase.date(from: record.created) else {
                continue
            }

            for stat in record.stats {
                let point = StatPoint(date: date, cpu: stat.cpu, memory: stat.memory)
                containerDict[stat.name, default: []].append(point)
            }
        }

        let result = containerDict.map { name, points in
            ProcessedContainerData(id: name, statPoints: points.sorted(by: { $0.date < $1.date }))
        }

        return result
    }
    private func transformSystem(records: [SystemStatsRecord]) -> [SystemDataPoint] {
        let dataPoints = records.compactMap { record -> SystemDataPoint? in
            guard let date = DateFormatter.pocketBase.date(from: record.created) else {
                return nil
            }

            let tempsArray = record.stats.temperatures.map { (name: $0.key, value: $0.value) }

            return SystemDataPoint(
                date: date,
                cpu: record.stats.cpu,
                memoryPercent: record.stats.memoryPercent,
                temperatures: tempsArray
            )
        }

        return dataPoints.sorted(by: { $0.date < $1.date })
    }
}
