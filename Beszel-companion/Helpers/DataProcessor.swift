import Foundation

struct DataProcessor {

    private static func parseTypeDuration(_ typeString: String) -> Int {
        return Int(typeString.replacingOccurrences(of: "m", with: "")) ?? Int.max
    }
    
    static func transformSystem(records: [SystemStatsRecord]) -> [SystemDataPoint] {
        let groupedByDate = Dictionary(grouping: records, by: { $0.created })
        
        let uniqueBestRecords = groupedByDate.compactMap { (_, recordsForDate) -> SystemStatsRecord? in
            if recordsForDate.count == 1 {
                return recordsForDate.first
            }

            return recordsForDate.min(by: { recordA, recordB in
                parseTypeDuration(recordA.type) < parseTypeDuration(recordB.type)
            })
        }

        let dataPoints = uniqueBestRecords.compactMap { record -> SystemDataPoint? in
            guard let date = DateFormatter.pocketBase.date(from: record.created) else {
                return nil
            }

            let tempsArray = (record.stats.temperatures ?? [:]).map { (name: $0.key, value: $0.value) }
            
            return SystemDataPoint(
                date: date,
                cpu: record.stats.cpu,
                memoryPercent: record.stats.memoryPercent,
                temperatures: tempsArray
            )
        }

        return dataPoints.sorted(by: { $0.date < $1.date })
    }
    
    static func transform(records: [ContainerStatsRecord]) -> [ProcessedContainerData] {
        var containerDict = [String: [StatPoint]]()

        for record in records {
            guard let date = DateFormatter.pocketBase.date(from: record.created) else {
                continue
            }

            for stat in record.stats {
                let point = StatPoint(date: date, cpu: stat.cpu, memory: stat.memory)
                containerDict[stat.name, default: []].append(point)
            }
        }

        let result = containerDict.map { name, points in
            ProcessedContainerData(id: name, statPoints: points.sorted(by: { $0.date < $1.date }))
        }

        return result
    }
}
