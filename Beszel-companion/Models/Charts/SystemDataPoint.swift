import Foundation

struct SystemDataPoint: Identifiable, Sendable {
    var id: Date { date }

    let date: Date
    let cpu: Double
    let memoryPercent: Double
    let temperatures: [(name: String, value: Double)]

    let bandwidth: (upload: Double, download: Double)?
    let diskIO: (read: Double, write: Double)?
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
}
