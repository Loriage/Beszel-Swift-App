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
    let diskRead: Double?
    let diskWrite: Double?
    let diskIO: [Double]?
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
        case bandwidth = "b"
        case diskRead = "dr"
        case diskWrite = "dw"
        case diskIO = "dio"
        case temperatures = "t"
        case load = "la"
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
            let stats = record.stats
            let tempsArray = (stats.temperatures ?? [:]).map { (name: $0.key, value: $0.value) }

            let bandwidthTuple: (upload: Double, download: Double)?
            if let b = stats.bandwidth, b.count >= 2 {
                bandwidthTuple = (upload: b[0], download: b[1])
            } else {
                let mbToBytes = 1_048_576.0
                bandwidthTuple = (upload: stats.networkSent * mbToBytes, download: stats.networkReceived * mbToBytes)
            }

            let diskIOTuple: (read: Double, write: Double)?
            if let dio = stats.diskIO, dio.count >= 2 {
                diskIOTuple = (read: dio[0], write: dio[1])
            } else if let dr = stats.diskRead, let dw = stats.diskWrite {
                let mbToBytes = 1_048_576.0
                diskIOTuple = (read: dr * mbToBytes, write: dw * mbToBytes)
            } else {
                diskIOTuple = nil
            }
            
            return SystemDataPoint(
                date: record.created,
                cpu: record.stats.cpu,
                memoryPercent: record.stats.memoryPercent,
                temperatures: tempsArray,
                bandwidth: bandwidthTuple,
                diskIO: diskIOTuple
            )
        }.sorted(by: { $0.date < $1.date })
    }
}
