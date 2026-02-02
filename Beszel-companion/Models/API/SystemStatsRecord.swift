import Foundation

nonisolated struct SystemStatsRecord: Identifiable, Codable, Sendable {
    let id: String
    let created: Date
    let stats: SystemStatsDetail
    let type: String
}

nonisolated struct SystemStatsDetail: Codable, Sendable {
    // CPU
    let cpu: Double
    let cpuPeak: Double?              // peak cpu
    let cpuBreakdown: [Double]?       // [user, system, iowait, steal, idle]
    let cpuPerCore: [Double]?         // per-core cpu usage

    // Load average
    let l1: Double?                   // load average 1 min
    let l5: Double?                   // load average 5 min
    let l15: Double?                  // load average 15 min
    let load: [Double]?               // load average array [1, 5, 15]

    // Memory
    let memoryTotal: Double?          // total memory (gb)
    let memoryUsed: Double            // memory used (gb)
    let memoryPercent: Double         // memory percent
    let memoryBuffer: Double?         // memory buffer + cache (gb)
    let memoryMax: Double?            // max used memory (gb)
    let memoryZfs: Double?            // zfs arc memory (gb)

    // Swap
    let swapTotal: Double?            // swap space (gb)
    let swapUsed: Double?             // swap used (gb)

    // Disk
    let diskTotal: Double?            // disk size (gb)
    let diskUsed: Double              // disk used (gb)
    let diskPercent: Double           // disk percent
    let diskRead: Double?             // disk read (mb)
    let diskWrite: Double?            // disk write (mb)
    let diskReadMax: Double?          // max disk read (mb)
    let diskWriteMax: Double?         // max disk write (mb)
    let diskIO: [Double]?             // disk I/O bytes [read, write]
    let diskIOMax: [Double]?          // max disk I/O bytes [read, write]

    // Network
    let networkSent: Double?          // network sent (mb)
    let networkReceived: Double?      // network received (mb)
    let bandwidth: [Double]?          // bandwidth bytes [sent, recv]
    let networkSentMax: Double?       // max network sent (mb)
    let networkReceivedMax: Double?   // max network received (mb)
    let bandwidthMax: [Double]?       // max bandwidth bytes [sent, recv]
    let networkInterfaces: [String: [Double]]?  // interface stats [sent, recv, sentMax, recvMax]

    // Temperatures
    let temperatures: [String: Double]?

    // Extra filesystems
    let extraFilesystems: [String: ExtraFsStats]?

    // GPU
    let gpu: [String: GPUData]?

    // Battery
    let battery: [Double]?            // [percent, state]

    enum CodingKeys: String, CodingKey {
        case cpu
        case cpuPeak = "cpum"
        case cpuBreakdown = "cpub"
        case cpuPerCore = "cpus"
        case l1, l5, l15
        case load = "la"
        case memoryTotal = "m"
        case memoryUsed = "mu"
        case memoryPercent = "mp"
        case memoryBuffer = "mb"
        case memoryMax = "mm"
        case memoryZfs = "mz"
        case swapTotal = "s"
        case swapUsed = "su"
        case diskTotal = "d"
        case diskUsed = "du"
        case diskPercent = "dp"
        case diskRead = "dr"
        case diskWrite = "dw"
        case diskReadMax = "drm"
        case diskWriteMax = "dwm"
        case diskIO = "dio"
        case diskIOMax = "diom"
        case networkSent = "ns"
        case networkReceived = "nr"
        case bandwidth = "b"
        case networkSentMax = "nsm"
        case networkReceivedMax = "nrm"
        case bandwidthMax = "bm"
        case networkInterfaces = "ni"
        case temperatures = "t"
        case extraFilesystems = "efs"
        case gpu = "g"
        case battery = "bat"
    }
}

nonisolated struct ExtraFsStats: Codable, Sendable {
    let d: Double?    // disk size (gb)
    let du: Double?   // disk used (gb)
    let dp: Double?   // disk percent
    let dr: Double?   // disk read (mb)
    let dw: Double?   // disk write (mb)
}

nonisolated struct GPUData: Codable, Sendable {
    let n: String?           // name
    let mu: Double?          // memory used
    let m: Double?           // memory total
    let u: Double?           // usage percent
    let p: Double?           // power watts
    let t: Double?           // temperature
    let e: [String: Double]? // engine utilization
}

extension SystemStatsDetail {
    static func sample() -> SystemStatsDetail {
        SystemStatsDetail(
            cpu: 45.0,
            cpuPeak: nil,
            cpuBreakdown: nil,
            cpuPerCore: nil,
            l1: 1.5,
            l5: 1.2,
            l15: 1.0,
            load: [1.5, 1.2, 1.0],
            memoryTotal: 16.0,
            memoryUsed: 4.0,
            memoryPercent: 60.0,
            memoryBuffer: nil,
            memoryMax: nil,
            memoryZfs: nil,
            swapTotal: nil,
            swapUsed: nil,
            diskTotal: 500.0,
            diskUsed: 50.0,
            diskPercent: 75.0,
            diskRead: nil,
            diskWrite: nil,
            diskReadMax: nil,
            diskWriteMax: nil,
            diskIO: nil,
            diskIOMax: nil,
            networkSent: 1024,
            networkReceived: 5120,
            bandwidth: nil,
            networkSentMax: nil,
            networkReceivedMax: nil,
            bandwidthMax: nil,
            networkInterfaces: nil,
            temperatures: [:],
            extraFilesystems: nil,
            gpu: nil,
            battery: nil
        )
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
            } else if let ns = stats.networkSent, let nr = stats.networkReceived {
                let mbToBytes = 1_048_576.0
                bandwidthTuple = (upload: ns * mbToBytes, download: nr * mbToBytes)
            } else {
                bandwidthTuple = nil
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
            
            let loadTuple: (l1: Double, l5: Double, l15: Double)?
            if let la = stats.load, la.count >= 3 {
                loadTuple = (l1: la[0], l5: la[1], l15: la[2])
            } else if let l1 = stats.l1, let l5 = stats.l5, let l15 = stats.l15 {
                loadTuple = (l1: l1, l5: l5, l15: l15)
            } else {
                loadTuple = nil
            }

            // Swap usage
            let swapTuple: (used: Double, total: Double)?
            if let swapUsed = stats.swapUsed, let swapTotal = stats.swapTotal, swapTotal > 0 {
                swapTuple = (used: swapUsed, total: swapTotal)
            } else {
                swapTuple = nil
            }

            // GPU metrics
            let gpuMetrics: [GPUMetricPoint] = (stats.gpu ?? [:]).compactMap { (name, data) in
                guard let usage = data.u else { return nil }
                return GPUMetricPoint(
                    name: data.n ?? name,
                    usage: usage,
                    memoryUsed: data.mu,
                    memoryTotal: data.m,
                    power: data.p,
                    temperature: data.t
                )
            }

            // Network interfaces
            let networkInterfaces: [NetworkInterfacePoint] = (stats.networkInterfaces ?? [:]).compactMap { (name, values) in
                guard values.count >= 2 else { return nil }
                return NetworkInterfacePoint(
                    name: name,
                    sent: values[0],
                    received: values[1]
                )
            }

            // Extra filesystems
            let extraFilesystems: [ExtraFilesystemPoint] = (stats.extraFilesystems ?? [:]).compactMap { (name, data) in
                guard let used = data.du, let total = data.d, let percent = data.dp else { return nil }
                return ExtraFilesystemPoint(
                    name: name,
                    used: used,
                    total: total,
                    percent: percent
                )
            }

            return SystemDataPoint(
                date: record.created,
                cpu: record.stats.cpu,
                memoryPercent: record.stats.memoryPercent,
                temperatures: tempsArray,
                bandwidth: bandwidthTuple,
                diskIO: diskIOTuple,
                loadAverage: loadTuple,
                swap: swapTuple,
                gpuMetrics: gpuMetrics,
                networkInterfaces: networkInterfaces,
                extraFilesystems: extraFilesystems
            )
        }.sorted(by: { $0.date < $1.date })
    }
}
