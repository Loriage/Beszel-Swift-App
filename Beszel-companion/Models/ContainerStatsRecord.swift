import Foundation

nonisolated struct ContainerStatsRecord: Identifiable, Codable, Sendable {
    let id: String
    let collectionId: String
    let collectionName: String
    let created: Date
    let updated: Date
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

extension Array where Element == ContainerStatsRecord {
    nonisolated func asProcessedData() -> [ProcessedContainerData] {
        var containerDict = [String: [StatPoint]]()
        
        for record in self {
            let date = record.created
            for stat in record.stats {
                let point = StatPoint(date: date, cpu: stat.cpu, memory: stat.memory)
                containerDict[stat.name, default: []].append(point)
            }
        }
        
        return containerDict.map { name, points in
            ProcessedContainerData(id: name, statPoints: points.sorted(by: { $0.date < $1.date }))
        }
    }
}
