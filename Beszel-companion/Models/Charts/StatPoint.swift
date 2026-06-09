import Foundation

struct StatPoint: Identifiable, Sendable, Hashable {
    var id: Date { date }
    let date: Date
    let cpu: Double
    let memory: Double
    let netSent: Double
    let netReceived: Double

    nonisolated init(date: Date, cpu: Double, memory: Double, netSent: Double = 0, netReceived: Double = 0) {
        self.date = date
        self.cpu = cpu
        self.memory = memory
        self.netSent = netSent
        self.netReceived = netReceived
    }
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
        let netSents = points.map { $0.netSent }
        let netReceiveds = points.map { $0.netReceived }

        guard let aggregatedDate = dates.min() else { return nil }

        let aggregatedCpu: Double
        let aggregatedMemory: Double
        let aggregatedNetSent: Double
        let aggregatedNetReceived: Double

        switch method {
        case .average:
            let count = Double(Swift.max(points.count, 1))
            aggregatedCpu = cpus.reduce(0, +) / count
            aggregatedMemory = memories.reduce(0, +) / count
            aggregatedNetSent = netSents.reduce(0, +) / count
            aggregatedNetReceived = netReceiveds.reduce(0, +) / count
        case .max:
            aggregatedCpu = cpus.max() ?? 0
            aggregatedMemory = memories.max() ?? 0
            aggregatedNetSent = netSents.max() ?? 0
            aggregatedNetReceived = netReceiveds.max() ?? 0
        case .median:
            let sortedCpus = cpus.sorted()
            let sortedMemories = memories.sorted()
            let sortedNetSents = netSents.sorted()
            let sortedNetReceiveds = netReceiveds.sorted()
            let cpuIndex = Swift.max(0, Swift.min(sortedCpus.count / 2, sortedCpus.count - 1))
            let memIndex = Swift.max(0, Swift.min(sortedMemories.count / 2, sortedMemories.count - 1))
            let netSentIndex = Swift.max(0, Swift.min(sortedNetSents.count / 2, sortedNetSents.count - 1))
            let netReceivedIndex = Swift.max(0, Swift.min(sortedNetReceiveds.count / 2, sortedNetReceiveds.count - 1))
            aggregatedCpu = sortedCpus.isEmpty ? 0 : sortedCpus[cpuIndex]
            aggregatedMemory = sortedMemories.isEmpty ? 0 : sortedMemories[memIndex]
            aggregatedNetSent = sortedNetSents.isEmpty ? 0 : sortedNetSents[netSentIndex]
            aggregatedNetReceived = sortedNetReceiveds.isEmpty ? 0 : sortedNetReceiveds[netReceivedIndex]
        }

        return StatPoint(date: aggregatedDate, cpu: aggregatedCpu, memory: aggregatedMemory, netSent: aggregatedNetSent, netReceived: aggregatedNetReceived)
    }
}
