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

        return SimpleEntry(
            date: Date(),
            chartType: chartType,
            dataPoints: sampleDataPoints(),
            systemInfo: .sample(),
            latestStats: .sample(),
            systemName: "My Server",
            status: "up",
            timeRange: .last24Hours
        )
    }
    
    func timeline(for configuration: SelectInstanceAndChartIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let chartType = WidgetChartType(rawValue: configuration.chart?.id ?? "") ?? defaultChartType

        let (instance, systemEntity, timeRange, filter, apiService) = await MainActor.run { () -> (Instance?, SystemEntity?, TimeRangeOption, String, BeszelAPIService?) in
            let settingsManager = SettingsManager()
            InstanceManager.shared.reloadFromStore()

            guard let instanceEntity = configuration.instance,
                  let instanceID = UUID(uuidString: instanceEntity.id),
                  let foundInstance = InstanceManager.shared.instances.first(where: { $0.id == instanceID }),
                  let sysEntity = configuration.system else {
                return (nil, nil, .last24Hours, "", nil)
            }

            let range = settingsManager.selectedTimeRange
            let filterString = "(\(settingsManager.selectedTimeRange.apiFilterString) && system = '\(sysEntity.id)')"
            let service = BeszelAPIService(instance: foundInstance, instanceManager: InstanceManager.shared)

            return (foundInstance, sysEntity, range, filterString, service)
        }

        guard let _ = instance,
              let systemEntity = systemEntity,
              let apiService = apiService else {
            let entry = SimpleEntry(date: .now, chartType: chartType, dataPoints: [], systemInfo: nil, latestStats: nil, systemName: "Unknown", status: nil, timeRange: .last24Hours, errorMessage: "widget.notConnected")
            return Timeline(entries: [entry], policy: .atEnd)
        }

        do {
            
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
                diskIO: nil,
                loadAverage: nil,
                swap: nil,
                gpuMetrics: [],
                networkInterfaces: [],
                extraFilesystems: []
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
