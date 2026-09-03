import WidgetKit
import SwiftUI
import os

private let widgetLogger = Logger(subsystem: "com.nohitdev.Beszel.widget", category: "Timeline")

struct SimpleEntry: TimelineEntry {
    let date: Date
    let chartType: WidgetChartType
    let dataPoints: [SystemDataPoint]
    let containerData: [ProcessedContainerData]
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
            containerData: [],
            systemInfo: nil,
            systemDetails: nil,
            latestStats: nil,
            systemName: String(localized: "System"),
            status: nil,
            timeRange: .last24Hours,
            lockScreenMetric: .cpu
        )
    }

    func snapshot(for configuration: SelectInstanceAndChartIntent, in context: Context) async -> SimpleEntry {
        let chartType = configuration.snapshotChartType(isPreview: context.isPreview, family: context.family)

        return SimpleEntry(
            date: Date(),
            chartType: chartType,
            dataPoints: sampleDataPoints(),
            containerData: sampleContainerData(),
            systemInfo: .sample(),
            systemDetails: nil,
            latestStats: .sample(),
            systemName: String(localized: "widget.sample.system"),
            status: "up",
            timeRange: .last24Hours,
            lockScreenMetric: .cpu,
            errorMessage: chartType.isAvailableInWidget ? nil : "widget.error.unsupportedChart"
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
            containerData: [],
            systemInfo: nil,
            systemDetails: nil,
            latestStats: nil,
            systemName: String(localized: "System"),
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
            containerData: [],
            systemInfo: .sample(),
            systemDetails: nil,
            latestStats: .sample(),
            systemName: String(localized: "widget.sample.system"),
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
            containerData: [],
            systemInfo: nil,
            systemDetails: nil,
            latestStats: nil,
            systemName: String(localized: "System"),
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
            containerData: [],
            systemInfo: .sample(),
            systemDetails: nil,
            latestStats: .sample(),
            systemName: String(localized: "widget.sample.system"),
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

    guard resolvedChartType.isAvailableInWidget else {
        let entry = SimpleEntry(
            date: .now,
            chartType: resolvedChartType,
            dataPoints: [],
            containerData: [],
            systemInfo: nil,
            systemDetails: nil,
            latestStats: nil,
            systemName: configurationSystemName ?? String(localized: "System"),
            status: nil,
            timeRange: .last24Hours,
            lockScreenMetric: lockScreenMetric,
            errorMessage: "widget.error.unsupportedChart"
        )
        return Timeline(entries: [entry], policy: .never)
    }

    let userDefaults = UserDefaults.sharedSuite
    let activeInstanceID = userDefaults.string(forKey: "activeInstanceID")
    let activeSystemID = userDefaults.string(forKey: "activeSystemID")
    
    let (instance, systemID, systemName, timeRange, apiService, instanceError) = await MainActor.run { () -> (Instance?, String?, String?, TimeRangeOption, BeszelAPIService?, String?) in
        let settingsManager = SettingsManager()
        InstanceManager.shared.reloadFromStore()
        
        let instanceCount = InstanceManager.shared.instances.count
        widgetLogger.info("Widget timeline: instances loaded = \(instanceCount)")
        
        let resolvedInstanceID = configurationInstanceID ?? activeInstanceID
        guard let instanceIDString = resolvedInstanceID else {
            widgetLogger.warning("Widget timeline: No instance ID available")
            return (nil, nil, nil, .last24Hours, nil, "widget.error.noInstance")
        }
        
        guard let instanceID = UUID(uuidString: instanceIDString) else {
            widgetLogger.error("Widget timeline: Invalid instance identifier")
            return (nil, nil, nil, .last24Hours, nil, "widget.error.noInstance")
        }
        
        guard let foundInstance = InstanceManager.shared.instances.first(where: { $0.id == instanceID }) else {
            widgetLogger.error("Widget timeline: Configured instance not found")
            return (nil, nil, nil, .last24Hours, nil, "widget.error.noInstance")
        }
        
        widgetLogger.debug("Widget timeline: Resolved configured instance")
        
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
        let entry = SimpleEntry(
            date: .now,
            chartType: resolvedChartType,
            dataPoints: [],
            containerData: [],
            systemInfo: nil,
            systemDetails: nil,
            latestStats: nil,
            systemName: String(localized: "Unknown"),
            status: nil,
            timeRange: .last24Hours,
            lockScreenMetric: lockScreenMetric,
            errorMessage: errorMessage
        )
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
            resolvedSystemName = systems.first(where: { $0.id == resolvedID })?.name ?? String(localized: "System")
        }
        
        guard let finalSystemID = resolvedSystemID else {
            widgetLogger.error("Widget timeline: No system found")
            let entry = SimpleEntry(
                date: .now,
                chartType: resolvedChartType,
                dataPoints: [],
                containerData: [],
                systemInfo: nil,
                systemDetails: nil,
                latestStats: nil,
                systemName: String(localized: "Unknown"),
                status: nil,
                timeRange: .last24Hours,
                lockScreenMetric: lockScreenMetric,
                errorMessage: "widget.error.noSystem"
            )
            return Timeline(entries: [entry], policy: .atEnd)
        }
        
        let filter = "(\(timeRange.apiFilterString) && system = '\(finalSystemID)')"
        async let statsTask: [SystemStatsRecord] = resolvedChartType.requiresContainerData
            ? []
            : apiService.fetchSystemStats(filter: filter)
        async let detailsTask: [SystemDetailsRecord] = (resolvedChartType == .systemInfo) ? apiService.fetchSystemDetails() : []
        async let containerRecordsTask: [ContainerStatsRecord] = resolvedChartType.requiresContainerData
            ? apiService.fetchMonitors(filter: filter)
            : []
        
        let records = try await statsTask
        let details = try await detailsTask
        let containerRecords = try await containerRecordsTask
        
        let dataPoints = records.asDataPoints()
        let containerData = containerRecords.asProcessedData()
        
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
            systemName: resolvedSystemName ?? String(localized: "System"),
            status: status,
            instanceID: resolvedInstanceID,
            systemID: finalSystemID
        )
        
        let entry = SimpleEntry(
            date: .now,
            chartType: resolvedChartType,
            dataPoints: dataPoints,
            containerData: containerData,
            systemInfo: fetchedInfo,
            systemDetails: fetchedDetails,
            latestStats: latestStats,
            systemName: resolvedSystemName ?? String(localized: "System"),
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
                containerData: [],
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
        
        let entry = SimpleEntry(
            date: .now,
            chartType: resolvedChartType,
            dataPoints: [],
            containerData: [],
            systemInfo: nil,
            systemDetails: nil,
            latestStats: nil,
            systemName: systemName ?? String(localized: "System"),
            status: nil,
            timeRange: .last24Hours,
            lockScreenMetric: lockScreenMetric,
            errorMessage: "widget.error.networkError"
        )
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60)))
    }
}

private func sampleDataPoints() -> [SystemDataPoint] {
    let pointCount = 24
    let endDate = Date.now

    return (0..<pointCount).map { index in
        let progress = Double(index) / Double(pointCount - 1)
        let wave = (sin(Double(index) * 0.62) + 1) / 2
        let secondaryWave = (cos(Double(index) * 0.38) + 1) / 2
        let cpu = min(92, 22 + wave * 18 + (index == 16 ? 42 : 0))
        let userCPU = cpu * 0.62
        let systemCPU = cpu * 0.25
        let ioWait = cpu * 0.09
        let steal = cpu * 0.04

        return SystemDataPoint(
            date: endDate.addingTimeInterval(TimeInterval(index - pointCount + 1) * 3_600),
            cpu: cpu,
            cpuBreakdown: [userCPU, systemCPU, ioWait, steal, max(0, 100 - cpu)],
            cpuPerCore: [
                min(100, cpu * 0.82),
                min(100, cpu * 1.12),
                min(100, cpu * 0.68 + secondaryWave * 8),
                min(100, cpu * 1.28)
            ],
            memoryPercent: 43 + progress * 7 + wave * 3,
            temperatures: [
                (name: "CPU", value: 47 + wave * 14),
                (name: "NVMe", value: 38 + secondaryWave * 8)
            ],
            bandwidth: (
                upload: 160_000 + wave * 840_000,
                download: 420_000 + secondaryWave * 2_800_000
            ),
            diskIO: (
                read: 180_000 + secondaryWave * 2_200_000,
                write: 90_000 + wave * 1_100_000
            ),
            diskIOStats: DiskIOStats(
                readTimePct: 5 + secondaryWave * 18,
                writeTimePct: 3 + wave * 12,
                utilPct: 12 + wave * 38,
                rAwait: 1.4 + secondaryWave * 4,
                wAwait: 2.1 + wave * 6,
                weightedIO: 0.3 + wave * 1.8
            ),
            diskUsage: (used: 318 + progress * 4, total: 512),
            loadAverage: (
                l1: 1.2 + wave * 2.2,
                l5: 1.1 + secondaryWave * 1.4,
                l15: 1.0 + progress * 0.8
            ),
            swap: (used: 1.4 + wave * 0.7, total: 8),
            gpuMetrics: [
                GPUMetricPoint(
                    name: "GPU 0",
                    usage: 18 + wave * 45,
                    memoryUsed: 2.8,
                    memoryTotal: 8,
                    power: 42,
                    temperature: 55 + wave * 9
                )
            ],
            networkInterfaces: [
                NetworkInterfacePoint(
                    name: "en0",
                    sent: 120_000 + wave * 540_000,
                    received: 360_000 + secondaryWave * 2_100_000,
                    totalSent: 8_200_000_000 + Double(index) * 24_000_000,
                    totalReceived: 42_000_000_000 + Double(index) * 86_000_000
                ),
                NetworkInterfacePoint(
                    name: "tailscale0",
                    sent: 40_000 + secondaryWave * 120_000,
                    received: 55_000 + wave * 210_000,
                    totalSent: 1_100_000_000 + Double(index) * 7_000_000,
                    totalReceived: 2_600_000_000 + Double(index) * 11_000_000
                )
            ],
            extraFilesystems: [
                ExtraFilesystemPoint(
                    name: "Data",
                    used: 742 + progress * 6,
                    total: 1_024,
                    percent: 72.5 + progress * 0.6,
                    diskRead: 90_000 + wave * 780_000,
                    diskWrite: 55_000 + secondaryWave * 420_000,
                    diskIOStats: DiskIOStats(
                        readTimePct: 4 + wave * 10,
                        writeTimePct: 3 + secondaryWave * 8,
                        utilPct: 9 + wave * 24,
                        rAwait: 1 + secondaryWave * 3,
                        wAwait: 1.8 + wave * 4,
                        weightedIO: 0.2 + wave
                    ),
                    totalRead: 12_000_000_000 + Double(index) * 400_000_000,
                    totalWrite: 6_000_000_000 + Double(index) * 200_000_000
                ),
                ExtraFilesystemPoint(
                    name: "Backup",
                    used: 1_260 + progress * 3,
                    total: 2_048,
                    percent: 61.5 + progress * 0.2,
                    diskRead: 35_000 + secondaryWave * 220_000,
                    diskWrite: 25_000 + wave * 150_000,
                    diskIOStats: DiskIOStats(
                        readTimePct: 2 + secondaryWave * 6,
                        writeTimePct: 2 + wave * 5,
                        utilPct: 5 + secondaryWave * 13,
                        rAwait: 0.8 + wave * 2,
                        wAwait: 1.2 + secondaryWave * 2.8,
                        weightedIO: 0.1 + secondaryWave * 0.6
                    ),
                    totalRead: 4_000_000_000 + Double(index) * 80_000_000,
                    totalWrite: 2_000_000_000 + Double(index) * 60_000_000
                )
            ],
            diskIOTotals: DiskIOTotals(
                read: 24_000_000_000 + Double(index) * 800_000_000,
                write: 16_000_000_000 + Double(index) * 400_000_000
            ),
            zfsPools: ["tank": ZFSPoolStats(
                d: 1_024, du: 320 + progress * 4,
                rb: 100_000 + wave * 1_200_000,
                wb: 80_000 + secondaryWave * 400_000, h: "ONLINE"
            )]
        )
    }
}

private func sampleContainerData() -> [ProcessedContainerData] {
    let pointCount = 24
    let endDate = Date.now
    let containers = [
        (name: "api", cpu: 18.0, memory: 420.0, network: 520_000.0),
        (name: "database", cpu: 12.0, memory: 860.0, network: 240_000.0),
        (name: "proxy", cpu: 5.0, memory: 145.0, network: 1_100_000.0),
        (name: "worker", cpu: 9.0, memory: 310.0, network: 180_000.0)
    ]

    return containers.enumerated().map { containerIndex, container in
        let points = (0..<pointCount).map { index in
            let wave = (sin(Double(index + containerIndex * 2) * 0.55) + 1) / 2
            return StatPoint(
                date: endDate.addingTimeInterval(TimeInterval(index - pointCount + 1) * 3_600),
                cpu: container.cpu * (0.65 + wave * 0.7),
                memory: container.memory * (0.94 + wave * 0.1),
                netSent: container.network * wave * 0.42,
                netReceived: container.network * (0.35 + wave * 0.65)
            )
        }
        return ProcessedContainerData(id: container.name, statPoints: points)
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
        BeszelDockerWidget()
        BeszelCircularWidget()
        BeszelRectangularWidget()
    }
}
