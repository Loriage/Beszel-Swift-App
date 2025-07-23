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

enum DownsampleMethod {
    case average
    case max
    case median
}

enum Tab {
    case home
    case system
    case container
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
