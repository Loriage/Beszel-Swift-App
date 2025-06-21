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
}
