import Foundation

enum DownsampleMethod {
    case average
    case max
    case median
}

extension Array where Element == StatPoint {
    func downsampled(bucketInterval: TimeInterval, method: DownsampleMethod) -> [StatPoint] {
        guard !isEmpty else { return [] }

        let sortedPoints = self.sorted { $0.date < $1.date }

        let minDate = sortedPoints.first!.date
        var downsampled: [StatPoint] = []

        var currentBucketStart = minDate
        var bucketPoints: [StatPoint] = []
        
        for point in sortedPoints {
            if point.date < currentBucketStart.addingTimeInterval(bucketInterval) {
                bucketPoints.append(point)
            } else {
                if !bucketPoints.isEmpty {
                    downsampled.append(aggregateBucket(bucketPoints, method: method, bucketStart: currentBucketStart))
                }

                currentBucketStart = point.date
                bucketPoints = [point]
            }
        }

        if !bucketPoints.isEmpty {
            downsampled.append(aggregateBucket(bucketPoints, method: method, bucketStart: currentBucketStart))
        }
        
        return downsampled
    }
    
    private func aggregateBucket(_ points: [StatPoint], method: DownsampleMethod, bucketStart: Date) -> StatPoint {
        guard !points.isEmpty else { fatalError("Bucket vide") }
        
        let dates = points.map { $0.date }
        let cpus = points.map { $0.cpu }
        let memories = points.map { $0.memory }
        
        let aggregatedDate = dates.min()!
        
        let aggregatedCpu: Double
        let aggregatedMemory: Double
        
        switch method {
        case .average:
            aggregatedCpu = cpus.reduce(0, +) / Double(cpus.count)
            aggregatedMemory = memories.reduce(0, +) / Double(memories.count)
        case .max:
            aggregatedCpu = cpus.max() ?? 0
            aggregatedMemory = memories.max() ?? 0
        case .median:
            let sortedCpus = cpus.sorted()
            let sortedMemories = memories.sorted()
            aggregatedCpu = sortedCpus[sortedCpus.count / 2]
            aggregatedMemory = sortedMemories[sortedMemories.count / 2]
        }
        
        return StatPoint(date: aggregatedDate, cpu: aggregatedCpu, memory: aggregatedMemory)
    }
}
