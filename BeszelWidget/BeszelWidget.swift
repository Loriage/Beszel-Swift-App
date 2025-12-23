import WidgetKit
import SwiftUI

struct SimpleEntry: TimelineEntry {
    let date: Date
    let chartType: WidgetChartType
    let dataPoints: [SystemDataPoint]
    let systemInfo: SystemInfo?
    let latestStats: SystemStatsDetail?
    let systemName: String
    let status: String?
    let timeRange: TimeRangeOption
    var errorMessage: String? = nil
}

struct Provider: AppIntentTimelineProvider {
    private let defaultChartType = WidgetChartType.systemInfo
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            chartType: defaultChartType,
            dataPoints: [],
            systemInfo: nil,
            latestStats: nil,
            systemName: "System",
            status: nil,
            timeRange: .last24Hours
        )
    }
    
    func snapshot(for configuration: SelectInstanceAndChartIntent, in context: Context) async -> SimpleEntry {
        let chartType = WidgetChartType(rawValue: configuration.chart?.id ?? "") ?? defaultChartType
        
        let sampleStats = SystemStatsDetail(
            cpu: 45.0,
            memoryPercent: 60.0,
            memoryUsed: 4 * 1024 * 1024 * 1024,
            diskUsed: 50 * 1024 * 1024 * 1024,
            diskPercent: 75.0,
            networkSent: 1024 * 1024,
            networkReceived: 5 * 1024 * 1024,
            bandwidth: nil,
            diskRead: nil,
            diskWrite: nil,
            diskIO: nil,
            temperatures: [:],
            load: [1.5, 1.2, 1.0]
        )
        
        let sampleInfo = SystemInfo(h: "server", k: "Linux", c: 4, t: 8, m: "Intel Core i7", os: 1, b: 0, u: 3600*24*3)
        
        return SimpleEntry(
            date: Date(),
            chartType: chartType,
            dataPoints: sampleDataPoints(),
            systemInfo: sampleInfo,
            latestStats: sampleStats,
            systemName: "My Server",
            status: "up",
            timeRange: .last24Hours
        )
    }
    
    func timeline(for configuration: SelectInstanceAndChartIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let settingsManager = SettingsManager()
        let chartType = WidgetChartType(rawValue: configuration.chart?.id ?? "") ?? defaultChartType
        
        await MainActor.run { InstanceManager.shared.reloadFromStore() }
        
        guard let instanceEntity = configuration.instance,
              let instanceID = UUID(uuidString: instanceEntity.id),
              let instance = await MainActor.run(body: { InstanceManager.shared.instances.first(where: { $0.id == instanceID }) }),
              let systemEntity = configuration.system else {
            
            let entry = SimpleEntry(date: .now, chartType: chartType, dataPoints: [], systemInfo: nil, latestStats: nil, systemName: "Unknown", status: nil, timeRange: .last24Hours, errorMessage: "widget.notConnected")
            return Timeline(entries: [entry], policy: .atEnd)
        }
        
        let apiService = await MainActor.run { BeszelAPIService(instance: instance, instanceManager: InstanceManager.shared) }
        
        do {
            let timeRange = await MainActor.run { settingsManager.selectedTimeRange }
            let filter = await MainActor.run { "(\(settingsManager.selectedTimeRange.apiFilterString) && system = '\(systemEntity.id)')" }
            
            async let statsTask = apiService.fetchSystemStats(filter: filter)
            async let systemsTask: [SystemRecord] = (chartType == .systemInfo) ? apiService.fetchSystems() : []
            
            let records = try await statsTask
            let systems = try await systemsTask
            
            let dataPoints = records.asDataPoints()
            
            var fetchedInfo: SystemInfo? = nil
            var latestStats: SystemStatsDetail? = nil
            var status: String? = nil
            
            if chartType == .systemInfo {
                if let lastRecord = records.max(by: { $0.created < $1.created }) {
                    latestStats = lastRecord.stats
                }
                
                if let foundSystem = systems.first(where: { $0.id == systemEntity.id }) {
                    fetchedInfo = foundSystem.info
                    status = foundSystem.status
                }
            }
            
            let entry = SimpleEntry(
                date: .now,
                chartType: chartType,
                dataPoints: dataPoints,
                systemInfo: fetchedInfo,
                latestStats: latestStats,
                systemName: systemEntity.name,
                status: status,
                timeRange: timeRange
            )
            
            let nextUpdate = Date().addingTimeInterval(15 * 60)
            return Timeline(entries: [entry], policy: .after(nextUpdate))
            
        } catch {
            let entry = SimpleEntry(date: .now, chartType: chartType, dataPoints: [], systemInfo: nil, latestStats: nil, systemName: systemEntity.name, status: nil, timeRange: .last24Hours, errorMessage: "widget.loadingError")
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60)))
        }
    }
    
    private func sampleDataPoints() -> [SystemDataPoint] {
        (0..<10).map { i in
            SystemDataPoint(
                date: Date().addingTimeInterval(TimeInterval(i * 3600)),
                cpu: Double.random(in: 20...80),
                memoryPercent: Double.random(in: 30...60),
                temperatures: [],
                bandwidth: nil,
                diskIO: nil
            )
        }
    }
}

@main
struct BeszelWidget: Widget {
    let kind: String = "BeszelWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectInstanceAndChartIntent.self, provider: Provider()) { entry in
            BeszelWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("widget.displayName")
        .description("widget.description")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
