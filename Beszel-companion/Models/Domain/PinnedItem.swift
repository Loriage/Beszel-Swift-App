import Foundation

enum PinnedItem: Codable, Hashable, Identifiable, Sendable {
    case systemInfo
    case systemCPU
    case systemMemory
    case systemTemperature
    case systemDiskIO
    case systemDiskIOUtilization
    case systemDiskIOTimes
    case systemDiskAwait
    case systemDiskIOQueueDepth
    case systemDiskUsage
    case systemBandwidth
    case systemBandwidthDownload
    case systemBandwidthUpload
    case systemBandwidthCumulativeDownload
    case systemBandwidthCumulativeUpload
    case systemLoadAverage
    case systemSwap
    case systemGPU
    case systemNetworkInterfaces
    case extraDiskUsage(name: String)
    case extraDiskIO(name: String)
    case extraDiskIOUtilization(name: String)
    case extraDiskIOTimes(name: String)
    case extraDiskAwait(name: String)
    case extraDiskIOQueueDepth(name: String)
    case containerCPU(name: String)
    case containerMemory(name: String)
    case stackedContainerCPU
    case stackedContainerMemory
    case stackedContainerNetwork

    var id: String {
        switch self {
        case .systemInfo: return "system_info"
        case .systemCPU: return "system_cpu"
        case .systemMemory: return "system_memory"
        case .systemTemperature: return "system_temperature"
        case .systemDiskIO: return "system_disk_io"
        case .systemDiskIOUtilization: return "system_disk_io_utilization"
        case .systemDiskIOTimes: return "system_disk_io_times"
        case .systemDiskAwait: return "system_disk_await"
        case .systemDiskIOQueueDepth: return "system_disk_io_queue_depth"
        case .systemDiskUsage: return "system_disk_usage"
        case .systemBandwidth: return "system_bandwidth"
        case .systemBandwidthDownload: return "system_bandwidth_download"
        case .systemBandwidthUpload: return "system_bandwidth_upload"
        case .systemBandwidthCumulativeDownload: return "system_bandwidth_cumulative_download"
        case .systemBandwidthCumulativeUpload: return "system_bandwidth_cumulative_upload"
        case .systemLoadAverage: return "system_loadaverage"
        case .systemSwap: return "system_swap"
        case .systemGPU: return "system_gpu"
        case .systemNetworkInterfaces: return "system_network_interfaces"
        case .extraDiskUsage(let name): return "extra_disk_usage_\(name)"
        case .extraDiskIO(let name): return "extra_disk_io_\(name)"
        case .extraDiskIOUtilization(let name): return "extra_disk_io_utilization_\(name)"
        case .extraDiskIOTimes(let name): return "extra_disk_io_times_\(name)"
        case .extraDiskAwait(let name): return "extra_disk_await_\(name)"
        case .extraDiskIOQueueDepth(let name): return "extra_disk_io_queue_depth_\(name)"
        case .containerCPU(let name): return "container_cpu_\(name)"
        case .containerMemory(let name): return "container_memory_\(name)"
        case .stackedContainerCPU: return "stacked_container_cpu"
        case .stackedContainerMemory: return "stacked_container_memory"
        case .stackedContainerNetwork: return "stacked_container_network"
        }
    }

    func localizedDisplayName(for bundle: Bundle) -> String {
        switch self {
        case .systemInfo:
            return NSLocalizedString("pinned.item.system.info", bundle: bundle, comment: "")
        case .systemCPU:
            return NSLocalizedString("pinned.item.system.cpu", bundle: bundle, comment: "")
        case .systemMemory:
            return NSLocalizedString("pinned.item.system.memory", bundle: bundle, comment: "")
        case .systemTemperature:
            return NSLocalizedString("pinned.item.system.temperature", bundle: bundle, comment: "")
        case .systemDiskIO:
            return NSLocalizedString("pinned.item.system.disk", bundle: bundle, comment: "")
        case .systemDiskIOUtilization:
            return NSLocalizedString("pinned.item.system.disk.utilization", bundle: bundle, comment: "")
        case .systemDiskIOTimes:
            return NSLocalizedString("pinned.item.system.disk.times", bundle: bundle, comment: "")
        case .systemDiskAwait:
            return NSLocalizedString("pinned.item.system.disk.await", bundle: bundle, comment: "")
        case .systemDiskIOQueueDepth:
            return NSLocalizedString("pinned.item.system.disk.queuedepth", bundle: bundle, comment: "")
        case .systemDiskUsage:
            return NSLocalizedString("pinned.item.system.diskusage", bundle: bundle, comment: "")
        case .systemBandwidth:
            return NSLocalizedString("pinned.item.system.bandwidth", bundle: bundle, comment: "")
        case .systemBandwidthDownload:
            return NSLocalizedString("pinned.item.system.bandwidth.download", bundle: bundle, comment: "")
        case .systemBandwidthUpload:
            return NSLocalizedString("pinned.item.system.bandwidth.upload", bundle: bundle, comment: "")
        case .systemBandwidthCumulativeDownload:
            return NSLocalizedString("pinned.item.system.bandwidth.cumulative.download", bundle: bundle, comment: "")
        case .systemBandwidthCumulativeUpload:
            return NSLocalizedString("pinned.item.system.bandwidth.cumulative.upload", bundle: bundle, comment: "")
        case .systemLoadAverage:
            return NSLocalizedString("pinned.item.system.loadaverage", bundle: bundle, comment: "")
        case .systemSwap:
            return NSLocalizedString("pinned.item.system.swap", bundle: bundle, comment: "")
        case .systemGPU:
            return NSLocalizedString("pinned.item.system.gpu", bundle: bundle, comment: "")
        case .systemNetworkInterfaces:
            return NSLocalizedString("pinned.item.system.networkinterfaces", bundle: bundle, comment: "")
        case .extraDiskUsage(let name):
            return "\(name) Usage"
        case .extraDiskIO(let name):
            return "\(name) I/O"
        case .extraDiskIOUtilization(let name):
            return "\(name) I/O Utilization"
        case .extraDiskIOTimes(let name):
            return "\(name) I/O Times"
        case .extraDiskAwait(let name):
            return "\(name) Await"
        case .extraDiskIOQueueDepth(let name):
            return "\(name) Queue Depth"
        case .containerCPU(let name):
            let format = NSLocalizedString("pinned.item.container.cpu", bundle: bundle, comment: "")
            return String(format: format, name)
        case .containerMemory(let name):
            let format = NSLocalizedString("pinned.item.container.memory", bundle: bundle, comment: "")
            return String(format: format, name)
        case .stackedContainerCPU:
            return NSLocalizedString("pinned.item.stacked.cpu", bundle: bundle, comment: "")
        case .stackedContainerMemory:
            return NSLocalizedString("pinned.item.stacked.memory", bundle: bundle, comment: "")
        case .stackedContainerNetwork:
            return NSLocalizedString("pinned.item.stacked.network", bundle: bundle, comment: "")
        }
    }

    var metricName: String {
        switch self {
        case .systemInfo: return "Info"
        case .systemCPU, .containerCPU, .stackedContainerCPU: return "CPU"
        case .systemMemory, .containerMemory, .stackedContainerMemory: return "Memory"
        case .stackedContainerNetwork: return "Network I/O"
        case .systemTemperature: return "Temperature"
        case .systemDiskIO: return "Disk I/O"
        case .systemDiskIOUtilization: return "Disk I/O Utilization"
        case .systemDiskIOTimes: return "Disk I/O Times"
        case .systemDiskAwait: return "Disk Await"
        case .systemDiskIOQueueDepth: return "Disk I/O Queue Depth"
        case .systemDiskUsage: return "Disk Usage"
        case .systemBandwidth: return "Bandwidth"
        case .systemBandwidthDownload: return "Bandwidth Download"
        case .systemBandwidthUpload: return "Bandwidth Upload"
        case .systemBandwidthCumulativeDownload: return "Cumulative Download"
        case .systemBandwidthCumulativeUpload: return "Cumulative Upload"
        case .systemLoadAverage: return "Load Average"
        case .systemSwap: return "Swap"
        case .systemGPU: return "GPU"
        case .systemNetworkInterfaces: return "Network Interfaces"
        case .extraDiskUsage(let name): return "\(name) Usage"
        case .extraDiskIO(let name): return "\(name) I/O"
        case .extraDiskIOUtilization(let name): return "\(name) I/O Utilization"
        case .extraDiskIOTimes(let name): return "\(name) I/O Times"
        case .extraDiskAwait(let name): return "\(name) Await"
        case .extraDiskIOQueueDepth(let name): return "\(name) Queue Depth"
        }
    }

    var serviceName: String {
        switch self {
        case .systemInfo:
            return "System_Info"
        case .containerCPU(let name), .containerMemory(let name):
            return name
        case .stackedContainerCPU, .stackedContainerMemory, .stackedContainerNetwork:
            return "Containers"
        default:
            return "System"
        }
    }
}

struct ResolvedPinnedItem: Identifiable, Hashable, Sendable {
    let item: PinnedItem
    let systemID: String

    var id: String {
        "\(systemID)-\(item.id)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ResolvedPinnedItem, rhs: ResolvedPinnedItem) -> Bool {
        lhs.id == rhs.id
    }
}
