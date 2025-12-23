import Foundation

enum PinnedItem: Codable, Hashable, Identifiable {
    case systemInfo
    case systemCPU
    case systemMemory
    case systemTemperature
    case systemDiskIO
    case systemBandwidth
    case systemLoadAverage
    case containerCPU(name: String)
    case containerMemory(name: String)
    case stackedContainerCPU
    case stackedContainerMemory
    
    var id: String {
        switch self {
        case .systemInfo: return "system_info"
        case .systemCPU: return "system_cpu"
        case .systemMemory: return "system_memory"
        case .systemTemperature: return "system_temperature"
        case .systemDiskIO: return "system_disk_io"
        case .systemBandwidth: return "system_bandwidth"
        case .systemLoadAverage: return "system_loadaverage"
        case .containerCPU(let name): return "container_cpu_\(name)"
        case .containerMemory(let name): return "container_memory_\(name)"
        case .stackedContainerCPU: return "stacked_container_cpu"
        case .stackedContainerMemory: return "stacked_container_memory"
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
        case .systemBandwidth:
            return NSLocalizedString("pinned.item.system.bandwidth", bundle: bundle, comment: "")
        case .systemLoadAverage:
            return NSLocalizedString("pinned.item.system.loadaverage", bundle: bundle, comment: "")
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
        }
    }
    
    var metricName: String {
        switch self {
        case .systemInfo: return "Info"
        case .systemCPU, .containerCPU, .stackedContainerCPU: return "CPU"
        case .systemMemory, .containerMemory, .stackedContainerMemory: return "Memory"
        case .systemTemperature: return "Temperature"
        case .systemDiskIO: return "Disk I/O"
        case .systemBandwidth: return "Bandwidth"
        case .systemLoadAverage: return "Load Average"
        }
    }
    
    var serviceName: String {
        switch self {
        case .systemInfo:
            return "System_Info"
        case .containerCPU(let name), .containerMemory(let name):
            return name
        case .stackedContainerCPU, .stackedContainerMemory:
            return "Containers"
        default:
            return "System"
        }
    }
}

struct ResolvedPinnedItem: Identifiable, Hashable {
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
