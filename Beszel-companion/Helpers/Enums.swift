import Foundation
import SwiftUI

enum SortOption: String, CaseIterable, Identifiable {
    case bySystem = "filter.bySystem"
    case byMetric = "filter.byMetric"
    case byService = "filter.byService"

    var id: String { self.rawValue }
}

enum TimeRangeOption: String, CaseIterable, Identifiable {
    case lastHour = "timeRange.lastHour"
    case last12Hours = "timeRange.last12Hours"
    case last24Hours = "timeRange.last24Hours"
    case last7Days = "timeRange.last7Days"
    case last30Days = "timeRange.last30Days"

    var id: String { self.rawValue }
}

enum PinnedItem: Codable, Hashable, Identifiable {
    case systemCPU
    case systemMemory
    case systemTemperature
    case containerCPU(name: String)
    case containerMemory(name: String)
    case stackedContainerCPU
    case stackedContainerMemory

    var id: String {
        switch self {
        case .systemCPU: return "system_cpu"
        case .systemMemory: return "system_memory"
        case .systemTemperature: return "system_temperature"
        case .containerCPU(let name): return "container_cpu_\(name)"
        case .containerMemory(let name): return "container_memory_\(name)"
        case .stackedContainerCPU: return "stacked_container_cpu"
        case .stackedContainerMemory: return "stacked_container_memory"
        }
    }

    func localizedDisplayName(for bundle: Bundle) -> String {
        switch self {
        case .systemCPU:
            return NSLocalizedString("pinned.item.system.cpu", bundle: bundle, comment: "")
        case .systemMemory:
            return NSLocalizedString("pinned.item.system.memory", bundle: bundle, comment: "")
        case .systemTemperature:
            return NSLocalizedString("pinned.item.system.temperature", bundle: bundle, comment: "")
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
        case .systemCPU, .containerCPU, .stackedContainerCPU: return "CPU"
        case .systemMemory, .containerMemory, .stackedContainerMemory: return "Memory"
        case .systemTemperature: return "Temperature"
        }
    }

    var serviceName: String {
        switch self {
        case .containerCPU(let name), .containerMemory(let name):
            return name
        case .stackedContainerCPU, .stackedContainerMemory:
            return "Containers"
        default:
            return "ZZZ_System"
        }
    }
}

enum DownsampleMethod {
    case average
    case max
    case median
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case system
    case container
    
    var id: String { self.rawValue }
}

public enum WidgetChartType: String, Sendable, CaseIterable {
    case systemCPU
    case systemMemory
    case systemTemperature
}

enum OnboardingError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case hubUnreachable

    var errorDescription: String? {
        switch self {
        case .hubUnreachable:
            return "Impossible de joindre le hub. Vérifiez l'URL et votre connexion."
        default:
            return "Une erreur est survenue."
        }
    }
}
