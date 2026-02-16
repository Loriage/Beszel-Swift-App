import WidgetKit
import SwiftUI
import os

private let widgetLogger = Logger(subsystem: "com.nohitdev.Beszel.widget", category: "Timeline")

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
    var errorMessage: LocalizedStringKey? = nil
    var isFromCache: Bool = false
}

private struct WidgetCache: Codable {
    let latestStats: SystemStatsDetail?
    let systemInfo: SystemInfo?
    let systemDetails: SystemDetailsRecord?
    let systemName: String
    let status: String?
    let cachedAt: Date
}

private enum WidgetCacheManager {
    private static let userDefaults = UserDefaults.sharedSuite

    static func cacheKey(instanceID: String?, systemID: String?) -> String {
        "widgetCache_\(instanceID ?? "default")_\(systemID ?? "default")"
    }

    static func save(
        latestStats: SystemStatsDetail?,
        systemInfo: SystemInfo?,
        systemDetails: SystemDetailsRecord?,
        systemName: String,
        status: String?,
        instanceID: String?,
        systemID: String?
    ) {
        let cache = WidgetCache(
            latestStats: latestStats,
            systemInfo: systemInfo,
            systemDetails: systemDetails,
            systemName: systemName,
            status: status,
            cachedAt: Date()
        )
        if let data = try? JSONEncoder().encode(cache) {
            userDefaults.set(data, forKey: cacheKey(instanceID: instanceID, systemID: systemID))
        }
    }

    static func load(instanceID: String?, systemID: String?) -> WidgetCache? {
        guard let data = userDefaults.data(forKey: cacheKey(instanceID: instanceID, systemID: systemID)),
              let cache = try? JSONDecoder().decode(WidgetCache.self, from: data) else {
            return nil
        }
        return cache
    }
}

extension SimpleEntry {
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

        return SimpleEntry(
            date: Date(),
            chartType: chartType,
            dataPoints: sampleDataPoints(),
            systemInfo: .sample(),
            systemDetails: nil,
            latestStats: .sample(),
            systemName: "My Server",
            status: "up",
            timeRange: .last24Hours,
            lockScreenMetric: .cpu
        )
    }

    func timeline(for configuration: SelectInstanceAndChartIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let chartType = WidgetChartType(rawValue: configuration.chart?.id ?? "") ?? defaultChartType

        return await buildTimeline(
            configurationInstanceID: configuration.instance?.id,
            configurationSystemID: configuration.system?.id,
            configurationSystemName: configuration.system?.name,
            chartType: chartType,
            lockScreenMetric: .cpu,
            context: context
        )
    }
}

struct CircularLockScreenProvider: AppIntentTimelineProvider {
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

struct RectangularLockScreenProvider: AppIntentTimelineProvider {
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

    func snapshot(for configuration: SelectInstanceIntent, in context: Context) async -> SimpleEntry {
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
            lockScreenMetric: .cpu
        )
    }

    func timeline(for configuration: SelectInstanceIntent, in context: Context) async -> Timeline<SimpleEntry> {
        return await buildTimeline(
            configurationInstanceID: configuration.instance?.id,
            configurationSystemID: configuration.system?.id,
            configurationSystemName: configuration.system?.name,
            chartType: WidgetChartType.systemInfo,
            lockScreenMetric: .cpu,
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
    let isLockScreen = context.family.isLockScreen
    let resolvedChartType: WidgetChartType = isLockScreen ? .systemInfo : chartType
    let userDefaults = UserDefaults.sharedSuite
    let activeInstanceID = userDefaults.string(forKey: "activeInstanceID")
    let activeSystemID = userDefaults.string(forKey: "activeSystemID")
    
    let (instance, systemID, systemName, timeRange, apiService, instanceError) = await MainActor.run { () -> (Instance?, String?, String?, TimeRangeOption, BeszelAPIService?, String?) in
        let settingsManager = SettingsManager()
        InstanceManager.shared.reloadFromStore()
        
        let instanceCount = InstanceManager.shared.instances.count
        widgetLogger.info("Widget timeline: instances loaded = \(instanceCount)")
        
        let resolvedInstanceID = configurationInstanceID ?? activeInstanceID
        widgetLogger.info("Widget timeline: configInstanceID=\(configurationInstanceID ?? "nil", privacy: .public), activeInstanceID=\(activeInstanceID ?? "nil", privacy: .public), resolved=\(resolvedInstanceID ?? "nil", privacy: .public)")
        
        guard let instanceIDString = resolvedInstanceID else {
            widgetLogger.warning("Widget timeline: No instance ID available")
            return (nil, nil, nil, .last24Hours, nil, "widget.error.noInstance")
        }
        
        guard let instanceID = UUID(uuidString: instanceIDString) else {
            widgetLogger.error("Widget timeline: Invalid UUID format: \(instanceIDString, privacy: .public)")
            return (nil, nil, nil, .last24Hours, nil, "widget.error.noInstance")
        }
        
        guard let foundInstance = InstanceManager.shared.instances.first(where: { $0.id == instanceID }) else {
            let availableIDs = InstanceManager.shared.instances.map { $0.id.uuidString }.joined(separator: ", ")
            widgetLogger.error("Widget timeline: Instance not found. Looking for: \(instanceIDString, privacy: .public), available: \(availableIDs, privacy: .public)")
            return (nil, nil, nil, .last24Hours, nil, "widget.error.noInstance")
        }
        
        widgetLogger.info("Widget timeline: Found instance '\(foundInstance.name, privacy: .public)'")
        
        let range: TimeRangeOption = isLockScreen ? .lastHour : settingsManager.selectedTimeRange
        let service = BeszelAPIService(instance: foundInstance, instanceManager: InstanceManager.shared)
        
        return (foundInstance, configurationSystemID ?? activeSystemID, configurationSystemName, range, service, nil)
    }
    
    guard let _ = instance,
          let apiService = apiService else {
        let errorMessage: LocalizedStringKey = if let instanceError {
            LocalizedStringKey(instanceError)
        } else {
            "widget.error.noInstance"
        }
        let entry = SimpleEntry(date: .now, chartType: resolvedChartType, dataPoints: [], systemInfo: nil, systemDetails: nil, latestStats: nil, systemName: "Unknown", status: nil, timeRange: .last24Hours, lockScreenMetric: lockScreenMetric, errorMessage: errorMessage)
        return Timeline(entries: [entry], policy: .atEnd)
    }
    
    var resolvedSystemID = systemID
    var resolvedSystemName = systemName

    do {
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
            widgetLogger.error("Widget timeline: No system found")
            let entry = SimpleEntry(date: .now, chartType: resolvedChartType, dataPoints: [], systemInfo: nil, systemDetails: nil, latestStats: nil, systemName: "Unknown", status: nil, timeRange: .last24Hours, lockScreenMetric: lockScreenMetric, errorMessage: "widget.error.noSystem")
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
        
        let resolvedInstanceID = configurationInstanceID ?? activeInstanceID
        WidgetCacheManager.save(
            latestStats: latestStats,
            systemInfo: fetchedInfo,
            systemDetails: fetchedDetails,
            systemName: resolvedSystemName ?? "System",
            status: status,
            instanceID: resolvedInstanceID,
            systemID: finalSystemID
        )
        
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
        widgetLogger.error("Widget timeline: Network error - \(error.localizedDescription, privacy: .public)")
        
        let resolvedInstanceID = configurationInstanceID ?? activeInstanceID
        
        if let cached = WidgetCacheManager.load(instanceID: resolvedInstanceID, systemID: resolvedSystemID) {
            widgetLogger.info("Widget timeline: Using cached data")
            let entry = SimpleEntry(
                date: .now,
                chartType: resolvedChartType,
                dataPoints: [],
                systemInfo: cached.systemInfo,
                systemDetails: cached.systemDetails,
                latestStats: cached.latestStats,
                systemName: cached.systemName,
                status: cached.status,
                timeRange: .last24Hours,
                lockScreenMetric: lockScreenMetric,
                isFromCache: true
            )
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60)))
        }
        
        let entry = SimpleEntry(date: .now, chartType: resolvedChartType, dataPoints: [], systemInfo: nil, systemDetails: nil, latestStats: nil, systemName: systemName ?? "System", status: nil, timeRange: .last24Hours, lockScreenMetric: lockScreenMetric, errorMessage: "widget.error.networkError")
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
            diskUsage: nil,
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

struct BeszelCircularWidget: Widget {
    let kind: String = "BeszelCircularWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectInstanceAndMetricIntent.self, provider: CircularLockScreenProvider()) { entry in
            BeszelWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("widget.circular.displayName")
        .description("widget.circular.description")
        .supportedFamilies([.accessoryCircular])
    }
}

struct BeszelRectangularWidget: Widget {
    let kind: String = "BeszelRectangularWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectInstanceIntent.self, provider: RectangularLockScreenProvider()) { entry in
            BeszelWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("widget.rectangular.displayName")
        .description("widget.rectangular.description")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

@main
struct BeszelWidgetBundle: WidgetBundle {
    var body: some Widget {
        BeszelWidget()
        BeszelCircularWidget()
        BeszelRectangularWidget()
    }
}
