import Foundation

struct DataProcessor {
    private static func parseTypeDuration(_ typeString: String) -> Int {
        return Int(typeString.replacingOccurrences(of: "m", with: "")) ?? Int.max
    }

    static func applyMovingAverage(to dataPoints: [SystemDataPoint], windowSize: Int) -> [SystemDataPoint] {
        guard dataPoints.count >= windowSize else {
            return dataPoints
        }

        var smoothedPoints: [SystemDataPoint] = []

        for i in 0...(dataPoints.count - windowSize) {
            let window = Array(dataPoints[i..<(i + windowSize)])

            let averageCpu = window.map { $0.cpu }.reduce(0, +) / Double(windowSize)
            let averageMemory = window.map { $0.memoryPercent }.reduce(0, +) / Double(windowSize)

            let lastPointInWindow = window.last!

            let smoothedPoint = SystemDataPoint(
                date: lastPointInWindow.date,
                cpu: averageCpu,
                memoryPercent: averageMemory,
                temperatures: lastPointInWindow.temperatures
            )

            smoothedPoints.append(smoothedPoint)
        }

        return smoothedPoints
    }

    static func transformSystem(records: [SystemStatsRecord]) -> [SystemDataPoint] {
        let groupedByDate = Dictionary(grouping: records, by: { String($0.created.prefix(16)) })

        let uniqueBestRecords = groupedByDate.compactMap { (_, recordsForMinute) -> SystemStatsRecord? in
            if recordsForMinute.count == 1 {
                return recordsForMinute.first
            }

            return recordsForMinute.min(by: { recordA, recordB in
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
