import Foundation

nonisolated struct ContainerRecord: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let collectionId: String
    let collectionName: String
    let name: String
    let cpu: Double
    let memory: Double
    let net: Double?
    let health: ContainerHealth?
    let status: String
    let image: String?
    let system: String
    let updated: Int64

    var updatedDate: Date {
        Date(timeIntervalSince1970: Double(updated) / 1000.0)
    }
}

nonisolated enum ContainerHealth: Int, Codable, Hashable, Sendable {
    case none = 0
    case starting = 1
    case healthy = 2
    case unhealthy = 3

    var displayTextKey: String {
        switch self {
        case .none: return "container.health.none"
        case .starting: return "container.health.starting"
        case .healthy: return "container.health.healthy"
        case .unhealthy: return "container.health.unhealthy"
        }
    }

    var displayText: String {
        String(localized: String.LocalizationValue(displayTextKey))
    }

    var color: String {
        switch self {
        case .none: return "secondary"
        case .starting: return "orange"
        case .healthy: return "green"
        case .unhealthy: return "red"
        }
    }
}
