import Foundation

nonisolated struct ContainerStatsRecord: Identifiable, Codable, Sendable {
    let id: String
    let collectionId: String
    let collectionName: String
    let created: String
    let updated: String
    let system: String
    let type: String
    let stats: [ContainerStat]
}

nonisolated struct ContainerStat: Identifiable, Codable, Hashable, Sendable {
    let name: String
    let cpu: Double
    let memory: Double
    let netSent: Double
    let netReceived: Double

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name = "n"
        case cpu = "c"
        case memory = "m"
        case netSent = "ns"
        case netReceived = "nr"
    }
}
