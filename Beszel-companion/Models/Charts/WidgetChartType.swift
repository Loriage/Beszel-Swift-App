import Foundation

public enum WidgetChartType: String, Sendable, CaseIterable {
    case systemInfo
    case systemCPU
    case systemCPUTimeBreakdown
    case systemCPUCores
    case systemMemory
    case systemTemperature
    case systemBattery
    case systemFans
    case systemDiskUsage
    case systemDiskIO
    case systemDiskIOUtilization
    case systemDiskIOTimes
    case systemDiskAwait
    case systemDiskIOQueueDepth
    case systemDiskCumulativeRead
    case systemDiskCumulativeWrite
    case zfsPoolUsage
    case zfsPoolIO
    case systemBandwidth
    case systemBandwidthDownload
    case systemBandwidthUpload
    case systemBandwidthCumulativeDownload
    case systemBandwidthCumulativeUpload
    case systemLoadAverage
    case systemSwap
    case systemGPU
    case systemNetworkInterfaces
    case extraDiskUsage
    case extraDiskIO
    case extraDiskIOUtilization
    case extraDiskIOTimes
    case extraDiskAwait
    case extraDiskIOQueueDepth
    case extraDiskCumulativeRead
    case extraDiskCumulativeWrite
    case containerCPU
    case containerMemory
    case containerNetwork

    public nonisolated var id: String { rawValue }

    public nonisolated var category: WidgetChartCategory {
        switch self {
        case .systemInfo: .overview
        case .systemCPU, .systemCPUTimeBreakdown, .systemCPUCores, .systemLoadAverage: .processor
        case .systemMemory, .systemSwap: .memory
        case .systemDiskUsage, .systemDiskIO, .systemDiskIOUtilization, .systemDiskIOTimes,
             .systemDiskAwait, .systemDiskIOQueueDepth: .disk
        case .systemDiskCumulativeRead, .systemDiskCumulativeWrite,
             .extraDiskCumulativeRead, .extraDiskCumulativeWrite: .diskTotals
        case .zfsPoolUsage, .zfsPoolIO: .zfs
        case .extraDiskUsage, .extraDiskIO, .extraDiskIOUtilization, .extraDiskIOTimes,
             .extraDiskAwait, .extraDiskIOQueueDepth: .additionalDisks
        case .systemBandwidth, .systemBandwidthDownload, .systemBandwidthUpload,
             .systemBandwidthCumulativeDownload, .systemBandwidthCumulativeUpload,
             .systemNetworkInterfaces: .network
        case .systemTemperature, .systemGPU, .systemBattery, .systemFans: .sensors
        case .containerCPU, .containerMemory, .containerNetwork: .overview
        }
    }

    public nonisolated static var selectableCases: [Self] {
        allCases.filter(\.isAvailableInWidget)
    }

    public nonisolated var isAvailableInWidget: Bool {
        switch self {
        case .systemCPUTimeBreakdown, .systemCPUCores,
             .containerCPU, .containerMemory, .containerNetwork:
            // Keep the identifiers for existing configurations, but do not offer
            // stacked charts until the widget can preserve their presentation.
            false
        default:
            true
        }
    }

    public nonisolated var titleKey: String {
        switch self {
        case .systemInfo: "pinned.item.system.info"
        case .systemCPU: "pinned.item.system.cpu"
        case .systemCPUTimeBreakdown: "pinned.item.system.cpu.breakdown"
        case .systemCPUCores: "pinned.item.system.cpu.cores"
        case .systemMemory: "pinned.item.system.memory"
        case .systemTemperature: "pinned.item.system.temperature"
        case .systemBattery: "chart.battery.title"
        case .systemFans: "chart.fans.title"
        case .systemDiskUsage: "pinned.item.system.diskusage"
        case .systemDiskIO: "pinned.item.system.disk"
        case .systemDiskIOUtilization: "pinned.item.system.disk.utilization"
        case .systemDiskIOTimes: "pinned.item.system.disk.times"
        case .systemDiskAwait: "pinned.item.system.disk.await"
        case .systemDiskIOQueueDepth: "pinned.item.system.disk.queuedepth"
        case .systemDiskCumulativeRead: "chart.disk.cumulativeRead"
        case .systemDiskCumulativeWrite: "chart.disk.cumulativeWrite"
        case .zfsPoolUsage: "widget.chart.zfsUsage"
        case .zfsPoolIO: "widget.chart.zfsIO"
        case .systemBandwidth: "pinned.item.system.bandwidth"
        case .systemBandwidthDownload: "pinned.item.system.bandwidth.download"
        case .systemBandwidthUpload: "pinned.item.system.bandwidth.upload"
        case .systemBandwidthCumulativeDownload: "pinned.item.system.bandwidth.cumulative.download"
        case .systemBandwidthCumulativeUpload: "pinned.item.system.bandwidth.cumulative.upload"
        case .systemLoadAverage: "pinned.item.system.loadaverage"
        case .systemSwap: "pinned.item.system.swap"
        case .systemGPU: "pinned.item.system.gpu"
        case .systemNetworkInterfaces: "pinned.item.system.networkinterfaces"
        case .extraDiskUsage: "widget.chart.extraDiskUsage.title"
        case .extraDiskIO: "widget.chart.extraDiskIO.title"
        case .extraDiskIOUtilization: "widget.chart.extraDiskIOUtilization.title"
        case .extraDiskIOTimes: "widget.chart.extraDiskIOTimes.title"
        case .extraDiskAwait: "widget.chart.extraDiskAwait.title"
        case .extraDiskIOQueueDepth: "widget.chart.extraDiskIOQueueDepth.title"
        case .extraDiskCumulativeRead: "widget.chart.extraDiskCumulativeRead"
        case .extraDiskCumulativeWrite: "widget.chart.extraDiskCumulativeWrite"
        case .containerCPU: "pinned.item.stacked.cpu"
        case .containerMemory: "pinned.item.stacked.memory"
        case .containerNetwork: "pinned.item.stacked.network"
        }
    }

    public nonisolated var localizedTitle: LocalizedStringResource {
        LocalizedStringResource(stringLiteral: titleKey)
    }

    public nonisolated var systemImage: String {
        switch self {
        case .systemInfo: "info.circle"
        case .systemCPU, .systemCPUTimeBreakdown, .systemCPUCores, .containerCPU: "cpu"
        case .systemMemory, .systemSwap, .containerMemory: "memorychip"
        case .systemTemperature: "thermometer.medium"
        case .systemBattery: "battery.75percent"
        case .systemFans: "fan"
        case .systemDiskUsage, .systemDiskIO, .systemDiskIOUtilization, .systemDiskIOTimes,
             .systemDiskAwait, .systemDiskIOQueueDepth, .systemDiskCumulativeRead, .systemDiskCumulativeWrite: "internaldrive"
        case .zfsPoolUsage, .zfsPoolIO: "externaldrive.badge.checkmark"
        case .systemBandwidth, .systemNetworkInterfaces, .containerNetwork: "network"
        case .systemBandwidthDownload, .systemBandwidthCumulativeDownload: "arrow.down.circle"
        case .systemBandwidthUpload, .systemBandwidthCumulativeUpload: "arrow.up.circle"
        case .systemLoadAverage: "waveform.path.ecg"
        case .systemGPU: "display"
        case .extraDiskUsage, .extraDiskIO, .extraDiskIOUtilization, .extraDiskIOTimes,
             .extraDiskAwait, .extraDiskIOQueueDepth, .extraDiskCumulativeRead, .extraDiskCumulativeWrite: "externaldrive"
        }
    }

    public nonisolated var requiresContainerData: Bool {
        switch self {
        case .containerCPU, .containerMemory, .containerNetwork:
            true
        default:
            false
        }
    }

    /// Optional hardware metrics are gated; older widget configurations retain their behavior.
    nonisolated func isSupported(by stats: SystemStatsDetail?) -> Bool {
        switch self {
        case .systemBattery: stats?.batteryPercent != nil || stats?.batteryReadings.isEmpty == false
        case .systemFans: stats?.fanReadings.isEmpty == false
        case .zfsPoolUsage, .zfsPoolIO: stats?.zfsPools?.isEmpty == false
        case .systemDiskCumulativeRead, .systemDiskCumulativeWrite: (stats?.diskIOTotals?.count ?? 0) >= 2
        case .extraDiskCumulativeRead: stats?.extraFilesystems?.values.contains { $0.tr != nil } == true
        case .extraDiskCumulativeWrite: stats?.extraFilesystems?.values.contains { $0.tw != nil } == true
        default: true
        }
    }
}

public nonisolated enum WidgetChartCategory: String, CaseIterable, Sendable {
    case overview
    case processor
    case memory
    case disk
    case additionalDisks
    case zfs
    case diskTotals
    case network
    case sensors

    public var title: LocalizedStringResource {
        switch self {
        case .overview: "widget.category.overview"
        case .processor: "widget.category.processor"
        case .memory: "widget.category.memory"
        case .disk: "widget.category.disk"
        case .additionalDisks: "widget.category.additionalDisks"
        case .zfs: "zfs.title"
        case .diskTotals: "widget.category.diskTotals"
        case .network: "widget.category.network"
        case .sensors: "widget.category.sensors"
        }
    }

    public var chartTypes: [WidgetChartType] {
        WidgetChartType.selectableCases.filter { $0.category == self }
    }
}
