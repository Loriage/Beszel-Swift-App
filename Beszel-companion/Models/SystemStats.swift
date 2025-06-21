import Foundation

struct SystemStatsRecord: Identifiable, Codable {
    let id: String
    let created: String
    let stats: SystemStatsDetail
}

struct SystemStatsDetail: Codable {
    let cpu: Double
    let memoryPercent: Double
    let memoryUsed: Double
    let diskUsed: Double
    let diskPercent: Double
    let networkSent: Double
    let networkReceived: Double

    let temperatures: [String: Double]

    enum CodingKeys: String, CodingKey {
        case cpu
        case memoryPercent = "mp"
        case memoryUsed = "mu"
        case diskUsed = "du"
        case diskPercent = "dp"
        case networkSent = "ns"
        case networkReceived = "nr"
        case temperatures = "t"
    }
}
