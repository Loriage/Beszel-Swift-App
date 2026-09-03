import Foundation

public enum WidgetChartType: String, Sendable, CaseIterable {
    case systemInfo
    case systemCPU
    case systemCPUTimeBreakdown
    case systemCPUCores
    case systemMemory
    case systemTemperature
    case systemDiskUsage
    case systemDiskIO
    case systemDiskIOUtilization
    case systemDiskIOTimes
    case systemDiskAwait
    case systemDiskIOQueueDepth
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
    case containerCPU
    case containerMemory
    case containerNetwork

    public nonisolated var id: String { rawValue }

    public nonisolated var titleKey: String {
        switch self {
        case .systemInfo: "pinned.item.system.info"
        case .systemCPU: "pinned.item.system.cpu"
        case .systemCPUTimeBreakdown: "pinned.item.system.cpu.breakdown"
        case .systemCPUCores: "pinned.item.system.cpu.cores"
        case .systemMemory: "pinned.item.system.memory"
        case .systemTemperature: "pinned.item.system.temperature"
        case .systemDiskUsage: "pinned.item.system.diskusage"
        case .systemDiskIO: "pinned.item.system.disk"
        case .systemDiskIOUtilization: "pinned.item.system.disk.utilization"
        case .systemDiskIOTimes: "pinned.item.system.disk.times"
        case .systemDiskAwait: "pinned.item.system.disk.await"
        case .systemDiskIOQueueDepth: "pinned.item.system.disk.queuedepth"
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
        case .systemDiskUsage, .systemDiskIO, .systemDiskIOUtilization, .systemDiskIOTimes,
             .systemDiskAwait, .systemDiskIOQueueDepth: "internaldrive"
        case .systemBandwidth, .systemNetworkInterfaces, .containerNetwork: "network"
        case .systemBandwidthDownload, .systemBandwidthCumulativeDownload: "arrow.down.circle"
        case .systemBandwidthUpload, .systemBandwidthCumulativeUpload: "arrow.up.circle"
        case .systemLoadAverage: "waveform.path.ecg"
        case .systemGPU: "display"
        case .extraDiskUsage, .extraDiskIO, .extraDiskIOUtilization, .extraDiskIOTimes,
             .extraDiskAwait, .extraDiskIOQueueDepth: "externaldrive"
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
}
