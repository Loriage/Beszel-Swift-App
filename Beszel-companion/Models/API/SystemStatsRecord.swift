import Foundation

nonisolated struct SystemStatsRecord: Identifiable, Codable, Sendable {
    let id: String
    let created: Date
    let stats: SystemStatsDetail
    let type: String
}

nonisolated struct SystemStatsDetail: Codable, Sendable {
    let cpu: Double
    let memoryPercent: Double
    let memoryUsed: Double
    let diskUsed: Double
    let diskPercent: Double
    let networkSent: Double
    let networkReceived: Double
    let bandwidth: [Double]?
    let temperatures: [String: Double]?
    let load: [Double]?
    
    enum CodingKeys: String, CodingKey {
        case cpu
        case memoryPercent = "mp"
        case memoryUsed = "mu"
        case diskUsed = "du"
        case diskPercent = "dp"
        case networkSent = "ns"
        case networkReceived = "nr"
        case temperatures = "t"
        case load = "la"
        case bandwidth = "b"
    }
}

extension Array where Element == SystemStatsRecord {
    nonisolated func asDataPoints() -> [SystemDataPoint] {
        let groupedByDate = Dictionary(grouping: self, by: { record in
            return Int(record.created.timeIntervalSince1970 / 60)
        })
        
        let uniqueBestRecords = groupedByDate.compactMap { (_, recordsForMinute) -> SystemStatsRecord? in
            if recordsForMinute.count == 1 { return recordsForMinute.first }
            
            return recordsForMinute.min(by: {
                let durA = Int($0.type.replacingOccurrences(of: "m", with: "")) ?? Int.max
                let durB = Int($1.type.replacingOccurrences(of: "m", with: "")) ?? Int.max
                return durA < durB
            })
        }
        
        return uniqueBestRecords.compactMap { record -> SystemDataPoint? in
            let tempsArray = (record.stats.temperatures ?? [:]).map { (name: $0.key, value: $0.value) }
            
            return SystemDataPoint(
                date: record.created,
                cpu: record.stats.cpu,
                memoryPercent: record.stats.memoryPercent,
                temperatures: tempsArray
            )
        }.sorted(by: { $0.date < $1.date })
    }
}
