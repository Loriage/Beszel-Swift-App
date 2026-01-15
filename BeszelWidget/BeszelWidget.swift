import WidgetKit
import SwiftUI

struct SimpleEntry: TimelineEntry {
    let date: Date
    let chartType: WidgetChartType
    let dataPoints: [SystemDataPoint]
    let systemInfo: SystemInfo?
    let systemDetails: SystemDetailsRecord?  // For Beszel agent 0.18.0+
    let latestStats: SystemStatsDetail?
    let systemName: String
    let status: String?
    let timeRange: TimeRangeOption
    let lockScreenMetric: LockScreenMetric
    var errorMessage: String? = nil

    /// CPU model from either system_details endpoint (0.18.0+) or legacy info field
    var cpuModel: String? {
        if let cpu = systemDetails?.cpu {
            return cpu
        }
        return systemInfo?.m
    }

    /// CPU cores from either system_details endpoint (0.18.0+) or legacy info field
    var cpuCores: Int? {
        if let cores = systemDetails?.cores {
            return cores
        }
        return systemInfo?.c
    }
}

struct Provider: AppIntentTimelineProvider {
    private let defaultChartType = WidgetChartType.systemInfo

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            chartType: defaultChartType,
            dataPoints: [],
            systemInfo: nil,
            systemDetails: nil,
            latestStats: nil,
            systemName: "System",
            status: nil,
            timeRange: .last24Hours,
            lockScreenMetric: .cpu
        )
    }

    func snapshot(for configuration: SelectInstanceAndChartIntent, in context: Context) async -> SimpleEntry {
        let chartType = WidgetChartType(rawValue: configuration.chart?.id ?? "") ?? defaultChartType
        let resolvedChartType: WidgetChartType = context.family.isLockScreen ? .systemInfo : chartType
        let lockScreenMetric = LockScreenMetric(metric: configuration.metric)

        return SimpleEntry(
            date: Date(),
            chartType: resolvedChartType,
            dataPoints: sampleDataPoints(),
            systemInfo: .sample(),
            systemDetails: nil,
            latestStats: .sample(),
            systemName: "My Server",
            status: "up",
            timeRange: .last24Hours,
            lockScreenMetric: lockScreenMetric
        )
    }

    func timeline(for configuration: SelectInstanceAndChartIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let chartType = WidgetChartType(rawValue: configuration.chart?.id ?? "") ?? defaultChartType
        let lockScreenMetric = LockScreenMetric(metric: configuration.metric)

        return await buildTimeline(
            configurationInstanceID: configuration.instance?.id,
            configurationSystemID: configuration.system?.id,
            configurationSystemName: configuration.system?.name,
            chartType: chartType,
            lockScreenMetric: lockScreenMetric,
            context: context
        )
    }
}

struct LockScreenProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            chartType: WidgetChartType.systemInfo,
            dataPoints: [],
            systemInfo: nil,
            systemDetails: nil,
            latestStats: nil,
            systemName: "System",
            status: nil,
            timeRange: .last24Hours,
            lockScreenMetric: .cpu
        )
    }

    func snapshot(for configuration: SelectInstanceAndMetricIntent, in context: Context) async -> SimpleEntry {
        let lockScreenMetric = LockScreenMetric(metric: configuration.metric)

        return SimpleEntry(
            date: Date(),
            chartType: WidgetChartType.systemInfo,
            dataPoints: [],
            systemInfo: .sample(),
            systemDetails: nil,
            latestStats: .sample(),
            systemName: "My Server",
            status: "up",
            timeRange: .last24Hours,
            lockScreenMetric: lockScreenMetric
        )
    }

    func timeline(for configuration: SelectInstanceAndMetricIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let lockScreenMetric = LockScreenMetric(metric: configuration.metric)

        return await buildTimeline(
            configurationInstanceID: configuration.instance?.id,
            configurationSystemID: configuration.system?.id,
            configurationSystemName: configuration.system?.name,
            chartType: WidgetChartType.systemInfo,
            lockScreenMetric: lockScreenMetric,
            context: context
        )
    }
}

private func buildTimeline(
    configurationInstanceID: String?,
    configurationSystemID: String?,
    configurationSystemName: String?,
    chartType: WidgetChartType,
    lockScreenMetric: LockScreenMetric,
    context: TimelineProviderContext
) async -> Timeline<SimpleEntry> {
    let resolvedChartType: WidgetChartType = context.family.isLockScreen ? .systemInfo : chartType
    let userDefaults = UserDefaults(suiteName: "group.com.nohitdev.Beszel")
    let activeInstanceID = userDefaults?.string(forKey: "activeInstanceID")
    let activeSystemID = userDefaults?.string(forKey: "activeSystemID")

    let (instance, systemID, systemName, timeRange, apiService) = await MainActor.run { () -> (Instance?, String?, String?, TimeRangeOption, BeszelAPIService?) in
        let settingsManager = SettingsManager()
        InstanceManager.shared.reloadFromStore()

        let resolvedInstanceID = configurationInstanceID ?? activeInstanceID
        guard let instanceIDString = resolvedInstanceID,
              let instanceID = UUID(uuidString: instanceIDString),
              let foundInstance = InstanceManager.shared.instances.first(where: { $0.id == instanceID }) else {
            return (nil, nil, nil, .last24Hours, nil)
        }

        let range = settingsManager.selectedTimeRange
        let service = BeszelAPIService(instance: foundInstance, instanceManager: InstanceManager.shared)

        return (foundInstance, configurationSystemID ?? activeSystemID, configurationSystemName, range, service)
    }

    guard let _ = instance,
          let apiService = apiService else {
        let entry = SimpleEntry(date: .now, chartType: resolvedChartType, dataPoints: [], systemInfo: nil, systemDetails: nil, latestStats: nil, systemName: "Unknown", status: nil, timeRange: .last24Hours, lockScreenMetric: lockScreenMetric, errorMessage: "widget.notConnected")
        return Timeline(entries: [entry], policy: .atEnd)
    }

    do {
        var resolvedSystemID = systemID
        var resolvedSystemName = systemName
        var systems: [SystemRecord] = []

        if resolvedSystemID == nil || resolvedSystemName == nil || resolvedChartType == .systemInfo {
            systems = try await apiService.fetchSystems()
        }

        if resolvedSystemID == nil {
            resolvedSystemID = systems.first?.id
        }

        if resolvedSystemName == nil, let resolvedID = resolvedSystemID {
            resolvedSystemName = systems.first(where: { $0.id == resolvedID })?.name ?? "System"
        }

        guard let finalSystemID = resolvedSystemID else {
            let entry = SimpleEntry(date: .now, chartType: resolvedChartType, dataPoints: [], systemInfo: nil, systemDetails: nil, latestStats: nil, systemName: "Unknown", status: nil, timeRange: .last24Hours, lockScreenMetric: lockScreenMetric, errorMessage: "widget.notConnected")
            return Timeline(entries: [entry], policy: .atEnd)
        }

        let filter = "(\(timeRange.apiFilterString) && system = '\(finalSystemID)')"
        async let statsTask = apiService.fetchSystemStats(filter: filter)
        async let detailsTask: [SystemDetailsRecord] = (resolvedChartType == .systemInfo) ? apiService.fetchSystemDetails() : []

        let records = try await statsTask
        let details = try await detailsTask

        let dataPoints = records.asDataPoints()

        var fetchedInfo: SystemInfo? = nil
        var fetchedDetails: SystemDetailsRecord? = nil
        var latestStats: SystemStatsDetail? = nil
        var status: String? = nil

        if resolvedChartType == .systemInfo {
            if let lastRecord = records.max(by: { $0.created < $1.created }) {
                latestStats = lastRecord.stats
            }

            if let foundSystem = systems.first(where: { $0.id == finalSystemID }) {
                fetchedInfo = foundSystem.info
                status = foundSystem.status
            }

            // Get system details for 0.18.0+ agents
            fetchedDetails = details.first(where: { $0.system == finalSystemID })
        }

        let entry = SimpleEntry(
            date: .now,
            chartType: resolvedChartType,
            dataPoints: dataPoints,
            systemInfo: fetchedInfo,
            systemDetails: fetchedDetails,
            latestStats: latestStats,
            systemName: resolvedSystemName ?? "System",
            status: status,
            timeRange: timeRange,
            lockScreenMetric: lockScreenMetric
        )

        let nextUpdate = Date().addingTimeInterval(15 * 60)
        return Timeline(entries: [entry], policy: .after(nextUpdate))

    } catch {
        let entry = SimpleEntry(date: .now, chartType: resolvedChartType, dataPoints: [], systemInfo: nil, systemDetails: nil, latestStats: nil, systemName: systemName ?? "System", status: nil, timeRange: .last24Hours, lockScreenMetric: lockScreenMetric, errorMessage: "widget.loadingError")
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

struct BeszelLockScreenWidget: Widget {
    let kind: String = "BeszelLockScreenWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectInstanceAndMetricIntent.self, provider: LockScreenProvider()) { entry in
            BeszelWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("widget.displayName")
        .description("widget.description")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct BeszelWidgetBundle: WidgetBundle {
    var body: some Widget {
        BeszelWidget()
        BeszelLockScreenWidget()
    }
}
