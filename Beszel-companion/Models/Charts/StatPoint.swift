import Foundation

struct StatPoint: Identifiable, Sendable, Hashable {
    var id: Date { date }
    let date: Date
    let cpu: Double
    let memory: Double
}

extension Array where Element == StatPoint {
    nonisolated func downsampled(bucketInterval: TimeInterval, method: DownsampleMethod) -> [StatPoint] {
        guard !isEmpty else { return [] }

        let sortedPoints = self.sorted { $0.date < $1.date }

        guard let firstPoint = sortedPoints.first else { return [] }
        let minDate = firstPoint.date
        var downsampled: [StatPoint] = []

        var currentBucketStart = minDate
        var bucketPoints: [StatPoint] = []
        
        for point in sortedPoints {
            if point.date < currentBucketStart.addingTimeInterval(bucketInterval) {
                bucketPoints.append(point)
            } else {
                if !bucketPoints.isEmpty, let aggregated = aggregateBucket(bucketPoints, method: method, bucketStart: currentBucketStart) {
                    downsampled.append(aggregated)
                }

                currentBucketStart = point.date
                bucketPoints = [point]
            }
        }

        if !bucketPoints.isEmpty, let aggregated = aggregateBucket(bucketPoints, method: method, bucketStart: currentBucketStart) {
            downsampled.append(aggregated)
        }
        
        return downsampled
    }
    
    nonisolated private func aggregateBucket(_ points: [StatPoint], method: DownsampleMethod, bucketStart: Date) -> StatPoint? {
        guard !points.isEmpty else { return nil }

        let dates = points.map { $0.date }
        let cpus = points.map { $0.cpu }
        let memories = points.map { $0.memory }

        guard let aggregatedDate = dates.min() else { return nil }

        let aggregatedCpu: Double
        let aggregatedMemory: Double

        switch method {
        case .average:
            aggregatedCpu = cpus.reduce(0, +) / Double(Swift.max(cpus.count, 1))
            aggregatedMemory = memories.reduce(0, +) / Double(Swift.max(memories.count, 1))
        case .max:
            aggregatedCpu = cpus.max() ?? 0
            aggregatedMemory = memories.max() ?? 0
        case .median:
            let sortedCpus = cpus.sorted()
            let sortedMemories = memories.sorted()
            let cpuIndex = Swift.max(0, Swift.min(sortedCpus.count / 2, sortedCpus.count - 1))
            let memIndex = Swift.max(0, Swift.min(sortedMemories.count / 2, sortedMemories.count - 1))
            aggregatedCpu = sortedCpus.isEmpty ? 0 : sortedCpus[cpuIndex]
            aggregatedMemory = sortedMemories.isEmpty ? 0 : sortedMemories[memIndex]
        }

        return StatPoint(date: aggregatedDate, cpu: aggregatedCpu, memory: aggregatedMemory)
    }
}
