import Foundation

enum PinnedItem: Codable, Hashable, Identifiable {
    case systemCPU
    case systemMemory
    case systemTemperature
    case containerCPU(name: String)
    case containerMemory(name: String)

    var id: String {
        switch self {
        case .systemCPU: return "system_cpu"
        case .systemMemory: return "system_memory"
        case .systemTemperature: return "system_temperature"
        case .containerCPU(let name): return "container_cpu_\(name)"
        case .containerMemory(let name): return "container_memory_\(name)"
        }
    }

    var displayName: String {
        switch self {
        case .systemCPU: return "CPU Système"
        case .systemMemory: return "Mémoire Système"
        case .systemTemperature: return "Température Système"
        case .containerCPU(let name): return "CPU: \(name)"
        case .containerMemory(let name): return "Mémoire: \(name)"
        }
    }

    var metricName: String {
        switch self {
        case .systemCPU, .containerCPU: return "CPU"
        case .systemMemory, .containerMemory: return "Mémoire"
        case .systemTemperature: return "Température"
        }
    }

    var serviceName: String {
        switch self {
        case .containerCPU(let name), .containerMemory(let name):
            return name
        default:
            return "ZZZ_Système"
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
