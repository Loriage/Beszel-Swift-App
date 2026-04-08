import Foundation

struct DiskIOStats: Sendable {
    let readTimePct: Double    // read time %
    let writeTimePct: Double   // write time %
    let utilPct: Double        // I/O utilization %
    let rAwait: Double         // read await (ms)
    let wAwait: Double         // write await (ms)
    let weightedIO: Double     // weighted I/O %
}

struct SystemDataPoint: Identifiable, Sendable {
    var id: Date { date }

    let date: Date
    let cpu: Double
    let cpuBreakdown: [Double]?   // [user, system, iowait, steal, idle] percentages
    let cpuPerCore: [Double]?     // per-core cpu %
    let memoryPercent: Double
    let temperatures: [(name: String, value: Double)]

    let bandwidth: (upload: Double, download: Double)?
    let diskIO: (read: Double, write: Double)?
    let diskIOStats: DiskIOStats?
    let diskUsage: (used: Double, total: Double)?
    let loadAverage: (l1: Double, l5: Double, l15: Double)?

    let swap: (used: Double, total: Double)?
    let gpuMetrics: [GPUMetricPoint]
    let networkInterfaces: [NetworkInterfacePoint]
    let extraFilesystems: [ExtraFilesystemPoint]
}

struct GPUMetricPoint: Identifiable, Sendable {
    var id: String { name }

    let name: String
    let usage: Double          // GPU utilization %
    let memoryUsed: Double?    // Memory used (bytes or GB)
    let memoryTotal: Double?   // Memory total
    let power: Double?         // Power watts
    let temperature: Double?   // Temperature
}

struct NetworkInterfacePoint: Identifiable, Sendable {
    var id: String { name }

    let name: String           // Interface name (eth0, wlan0, etc.)
    let sent: Double           // Bytes sent
    let received: Double       // Bytes received
}

struct ExtraFilesystemPoint: Identifiable, Sendable {
    var id: String { name }

    let name: String           // Mount point or label
    let used: Double           // Disk used (GB)
    let total: Double          // Disk total (GB)
    let percent: Double        // Usage percent
    let diskRead: Double?      // Disk read (bytes/s)
    let diskWrite: Double?     // Disk write (bytes/s)
    let diskIOStats: DiskIOStats?
}

// Downsampling for SystemDataPoint
extension Array where Element == SystemDataPoint {
    nonisolated func downsampled(bucketInterval: TimeInterval) -> [SystemDataPoint] {
        guard !isEmpty else { return [] }

        let sortedPoints = self.sorted { $0.date < $1.date }
        guard let firstPoint = sortedPoints.first else { return [] }

        var downsampled: [SystemDataPoint] = []
        var currentBucketStart = firstPoint.date
        var bucketPoints: [SystemDataPoint] = []

        for point in sortedPoints {
            if point.date < currentBucketStart.addingTimeInterval(bucketInterval) {
                bucketPoints.append(point)
            } else {
                if !bucketPoints.isEmpty, let aggregated = aggregateBucket(bucketPoints) {
                    downsampled.append(aggregated)
                }
                currentBucketStart = point.date
                bucketPoints = [point]
            }
        }

        if !bucketPoints.isEmpty, let aggregated = aggregateBucket(bucketPoints) {
            downsampled.append(aggregated)
        }

        return downsampled
    }

    nonisolated private func aggregateBucket(_ points: [SystemDataPoint]) -> SystemDataPoint? {
        guard !points.isEmpty, let firstDate = points.map({ $0.date }).min() else { return nil }

        let count = Double(points.count)

        // Average CPU and memory
        let avgCpu = points.map { $0.cpu }.reduce(0, +) / count
        let avgMemory = points.map { $0.memoryPercent }.reduce(0, +) / count

        // Average temperatures by name
        var tempSums: [String: (sum: Double, count: Int)] = [:]
        for point in points {
            for temp in point.temperatures {
                let existing = tempSums[temp.name] ?? (0, 0)
                tempSums[temp.name] = (existing.sum + temp.value, existing.count + 1)
            }
        }
        let avgTemps = tempSums.map { (name: $0.key, value: $0.value.sum / Double($0.value.count)) }

        // Average bandwidth
        let bandwidthPoints = points.compactMap { $0.bandwidth }
        let avgBandwidth: (upload: Double, download: Double)?
        if !bandwidthPoints.isEmpty {
            let bCount = Double(bandwidthPoints.count)
            avgBandwidth = (
                upload: bandwidthPoints.map { $0.upload }.reduce(0, +) / bCount,
                download: bandwidthPoints.map { $0.download }.reduce(0, +) / bCount
            )
        } else {
            avgBandwidth = nil
        }

        // Average diskIO
        let diskIOPoints = points.compactMap { $0.diskIO }
        let avgDiskIO: (read: Double, write: Double)?
        if !diskIOPoints.isEmpty {
            let dCount = Double(diskIOPoints.count)
            avgDiskIO = (
                read: diskIOPoints.map { $0.read }.reduce(0, +) / dCount,
                write: diskIOPoints.map { $0.write }.reduce(0, +) / dCount
            )
        } else {
            avgDiskIO = nil
        }

        // Average diskIOStats
        let diskIOStatsPoints = points.compactMap { $0.diskIOStats }
        let avgDiskIOStats: DiskIOStats?
        if !diskIOStatsPoints.isEmpty {
            let dCount = Double(diskIOStatsPoints.count)
            avgDiskIOStats = DiskIOStats(
                readTimePct: diskIOStatsPoints.map { $0.readTimePct }.reduce(0, +) / dCount,
                writeTimePct: diskIOStatsPoints.map { $0.writeTimePct }.reduce(0, +) / dCount,
                utilPct: diskIOStatsPoints.map { $0.utilPct }.reduce(0, +) / dCount,
                rAwait: diskIOStatsPoints.map { $0.rAwait }.reduce(0, +) / dCount,
                wAwait: diskIOStatsPoints.map { $0.wAwait }.reduce(0, +) / dCount,
                weightedIO: diskIOStatsPoints.map { $0.weightedIO }.reduce(0, +) / dCount
            )
        } else {
            avgDiskIOStats = nil
        }

        // Average disk usage
        let diskUsagePoints = points.compactMap { $0.diskUsage }
        let avgDiskUsage: (used: Double, total: Double)?
        if !diskUsagePoints.isEmpty {
            let duCount = Double(diskUsagePoints.count)
            avgDiskUsage = (
                used: diskUsagePoints.map { $0.used }.reduce(0, +) / duCount,
                total: diskUsagePoints.map { $0.total }.max() ?? 0
            )
        } else {
            avgDiskUsage = nil
        }

        // Average load average
        let loadPoints = points.compactMap { $0.loadAverage }
        let avgLoad: (l1: Double, l5: Double, l15: Double)?
        if !loadPoints.isEmpty {
            let lCount = Double(loadPoints.count)
            avgLoad = (
                l1: loadPoints.map { $0.l1 }.reduce(0, +) / lCount,
                l5: loadPoints.map { $0.l5 }.reduce(0, +) / lCount,
                l15: loadPoints.map { $0.l15 }.reduce(0, +) / lCount
            )
        } else {
            avgLoad = nil
        }

        // Average swap
        let swapPoints = points.compactMap { $0.swap }
        let avgSwap: (used: Double, total: Double)?
        if !swapPoints.isEmpty {
            let sCount = Double(swapPoints.count)
            avgSwap = (
                used: swapPoints.map { $0.used }.reduce(0, +) / sCount,
                total: swapPoints.map { $0.total }.reduce(0, +) / sCount
            )
        } else {
            avgSwap = nil
        }

        // Average GPU metrics by name
        var gpuSums: [String: (usage: Double, memUsed: Double, memTotal: Double, power: Double, temp: Double, count: Int)] = [:]
        for point in points {
            for gpu in point.gpuMetrics {
                let existing = gpuSums[gpu.name] ?? (0, 0, 0, 0, 0, 0)
                gpuSums[gpu.name] = (
                    usage: existing.usage + gpu.usage,
                    memUsed: existing.memUsed + (gpu.memoryUsed ?? 0),
                    memTotal: existing.memTotal + (gpu.memoryTotal ?? 0),
                    power: existing.power + (gpu.power ?? 0),
                    temp: existing.temp + (gpu.temperature ?? 0),
                    count: existing.count + 1
                )
            }
        }
        let avgGpuMetrics = gpuSums.map { (name, data) -> GPUMetricPoint in
            let c = Double(data.count)
            return GPUMetricPoint(
                name: name,
                usage: data.usage / c,
                memoryUsed: data.memUsed > 0 ? data.memUsed / c : nil,
                memoryTotal: data.memTotal > 0 ? data.memTotal / c : nil,
                power: data.power > 0 ? data.power / c : nil,
                temperature: data.temp > 0 ? data.temp / c : nil
            )
        }

        // Average network interfaces by name
        var netSums: [String: (sent: Double, received: Double, count: Int)] = [:]
        for point in points {
            for iface in point.networkInterfaces {
                let existing = netSums[iface.name] ?? (0, 0, 0)
                netSums[iface.name] = (
                    sent: existing.sent + iface.sent,
                    received: existing.received + iface.received,
                    count: existing.count + 1
                )
            }
        }
        let avgNetInterfaces = netSums.map { (name, data) -> NetworkInterfacePoint in
            let c = Double(data.count)
            return NetworkInterfacePoint(name: name, sent: data.sent / c, received: data.received / c)
        }

        // Average extra filesystems by name
        typealias FsSums = (used: Double, maxTotal: Double, percent: Double, diskRead: Double, diskWrite: Double, ioCount: Int, count: Int, diosRTp: Double, diosWTp: Double, diosUtil: Double, diosRA: Double, diosWA: Double, diosWIO: Double, diosCount: Int)
        var fsSums: [String: FsSums] = [:]
        for point in points {
            for fs in point.extraFilesystems {
                let ex: FsSums = fsSums[fs.name] ?? (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
                let s = fs.diskIOStats
                fsSums[fs.name] = (
                    used: ex.used + fs.used,
                    maxTotal: Swift.max(ex.maxTotal, fs.total),
                    percent: ex.percent + fs.percent,
                    diskRead: ex.diskRead + (fs.diskRead ?? 0),
                    diskWrite: ex.diskWrite + (fs.diskWrite ?? 0),
                    ioCount: ex.ioCount + (fs.diskRead != nil ? 1 : 0),
                    count: ex.count + 1,
                    diosRTp: ex.diosRTp + (s?.readTimePct ?? 0),
                    diosWTp: ex.diosWTp + (s?.writeTimePct ?? 0),
                    diosUtil: ex.diosUtil + (s?.utilPct ?? 0),
                    diosRA: ex.diosRA + (s?.rAwait ?? 0),
                    diosWA: ex.diosWA + (s?.wAwait ?? 0),
                    diosWIO: ex.diosWIO + (s?.weightedIO ?? 0),
                    diosCount: ex.diosCount + (s != nil ? 1 : 0)
                )
            }
        }
        let avgExtraFs = fsSums.map { (name, data) -> ExtraFilesystemPoint in
            let c = Double(data.count)
            let ioC = Double(data.ioCount)
            let dC = Double(data.diosCount)
            let avgDios: DiskIOStats? = dC > 0 ? DiskIOStats(
                readTimePct: data.diosRTp / dC,
                writeTimePct: data.diosWTp / dC,
                utilPct: data.diosUtil / dC,
                rAwait: data.diosRA / dC,
                wAwait: data.diosWA / dC,
                weightedIO: data.diosWIO / dC
            ) : nil
            return ExtraFilesystemPoint(
                name: name,
                used: data.used / c,
                total: data.maxTotal,
                percent: data.percent / c,
                diskRead: ioC > 0 ? data.diskRead / ioC : nil,
                diskWrite: ioC > 0 ? data.diskWrite / ioC : nil,
                diskIOStats: avgDios
            )
        }

        // Average cpuBreakdown element-wise
        let breakdownPoints = points.compactMap { $0.cpuBreakdown }
        let avgCpuBreakdown: [Double]?
        if let first = breakdownPoints.first, !first.isEmpty {
            let bdCount = Double(breakdownPoints.count)
            avgCpuBreakdown = (0..<first.count).map { i in
                breakdownPoints.compactMap { i < $0.count ? $0[i] : nil }.reduce(0, +) / bdCount
            }
        } else {
            avgCpuBreakdown = nil
        }

        // Average cpuPerCore element-wise
        let perCorePoints = points.compactMap { $0.cpuPerCore }
        let avgCpuPerCore: [Double]?
        if let first = perCorePoints.first, !first.isEmpty {
            let pcCount = Double(perCorePoints.count)
            avgCpuPerCore = (0..<first.count).map { i in
                perCorePoints.compactMap { i < $0.count ? $0[i] : nil }.reduce(0, +) / pcCount
            }
        } else {
            avgCpuPerCore = nil
        }

        return SystemDataPoint(
            date: firstDate,
            cpu: avgCpu,
            cpuBreakdown: avgCpuBreakdown,
            cpuPerCore: avgCpuPerCore,
            memoryPercent: avgMemory,
            temperatures: avgTemps,
            bandwidth: avgBandwidth,
            diskIO: avgDiskIO,
            diskIOStats: avgDiskIOStats,
            diskUsage: avgDiskUsage,
            loadAverage: avgLoad,
            swap: avgSwap,
            gpuMetrics: avgGpuMetrics,
            networkInterfaces: avgNetInterfaces,
            extraFilesystems: avgExtraFs
        )
    }
}
