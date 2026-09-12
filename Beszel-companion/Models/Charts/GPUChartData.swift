import Foundation

nonisolated enum GPUChartMetric: String, CaseIterable, Sendable {
    case usage, power, memory, engines

    var title: LocalizedStringResource {
        switch self {
        case .usage: "chart.gpuUsage"
        case .power: "chart.gpu.power"
        case .memory: "chart.gpu.memory"
        case .engines: "chart.gpu.engines"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .usage: "chart.gpuUsage.subtitle"
        case .power: "chart.gpu.power.subtitle"
        case .memory: "chart.gpu.memory.subtitle"
        case .engines: "chart.gpu.engines.subtitle"
        }
    }

    var unit: String {
        switch self {
        case .usage, .engines: "%"
        case .power: "W"
        case .memory: "MiB"
        }
    }

    func formatted(_ value: Double, locale: Locale = .current) -> String {
        if self == .usage || self == .engines {
            return (value / 100).formatted(.percent.locale(locale).precision(.fractionLength(0...1)))
        }
        if self == .memory, value >= 1024 {
            return (value / 1024).formatted(.number.locale(locale).precision(.fractionLength(0...1))) + " GiB"
        }
        return value.formatted(.number.locale(locale).precision(.fractionLength(0...2))) + " " + unit
    }

    func pinnedItem(deviceID: String? = nil) -> PinnedItem {
        switch self {
        case .usage: .systemGPU
        case .power: .systemGPUPower
        case .memory: .gpuMemory(id: deviceID ?? "")
        case .engines: .gpuEngines(id: deviceID ?? "")
        }
    }

    static func valid(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }
}

nonisolated struct GPUChartDevice: Identifiable, Sendable {
    let id: String
    let name: String
}

nonisolated struct GPUChartSeries: Identifiable, Sendable {
    let id: String
    let name: String
    let styleIndex: Int
    let isReference: Bool
    let samples: [SensorChartSample]
    let currentValue: Double?
}

/// Shared preparation keeps app charts and widgets consistent, including gaps and GPU identity.
nonisolated struct GPUChartData: Sendable {
    let metric: GPUChartMetric
    let device: GPUChartDevice?
    let series: [GPUChartSeries]
    let latestDate: Date?
    let yDomain: ClosedRange<Double>

    static func devices(in points: [SystemDataPoint]) -> [GPUChartDevice] {
        let grouped = Dictionary(grouping: points.sorted { $0.date < $1.date }.flatMap(\.gpuMetrics), by: \.id)
        let names = grouped.compactMapValues { $0.last?.name }
        return names.keys.sorted().map { id in
            let name = names[id] ?? id
            let duplicated = names.values.filter { $0 == name }.count > 1
            return GPUChartDevice(id: id, name: duplicated ? "\(name) (\(id))" : name)
        }
    }

    init(metric: GPUChartMetric, dataPoints: [SystemDataPoint], deviceID: String? = nil) {
        self.metric = metric
        let points = dataPoints.sorted { $0.date < $1.date }
        let devices = Self.devices(in: points)
        device = devices.first { $0.id == deviceID }
        latestDate = points.last?.date
        var result: [GPUChartSeries] = []
        for (index, device) in devices.enumerated() where deviceID == nil || device.id == deviceID {
            func append(_ suffix: String, name: String, reference: Bool = false, value: (GPUMetricPoint) -> Double?) {
                var segment = 0
                let samples: [SensorChartSample] = points.compactMap { point in
                    guard let gpu = point.gpuMetrics.first(where: { $0.id == device.id }),
                          let reading = GPUChartMetric.valid(value(gpu)) else {
                        segment += 1
                        return nil
                    }
                    return SensorChartSample(date: point.date, value: reading, segment: segment)
                }
                guard !samples.isEmpty else { return }
                result.append(GPUChartSeries(
                    id: "\(device.id.utf8.count):\(device.id):\(suffix)", name: name,
                    styleIndex: metric == .engines ? result.count : index,
                    isReference: reference, samples: samples,
                    currentValue: samples.last.flatMap { $0.date == points.last?.date ? $0.value : nil }
                ))
            }
            switch metric {
            case .usage:
                append("usage", name: device.name) { $0.usage }
            case .power:
                append("power", name: device.name) { $0.power }
                // Agents also send pp: 0 for discrete GPUs. Only show a measured package.
                if points.contains(where: { $0.gpuMetrics.contains { $0.id == device.id && (GPUChartMetric.valid($0.packagePower) ?? 0) > 0 } }) {
                    append("package", name: String(localized: "chart.gpu.package \(device.name)"), reference: true) { $0.packagePower }
                }
            case .memory:
                append("used", name: deviceID == nil ? String(localized: "chart.gpu.used \(device.name)") : String(localized: "chart.swap.used")) { $0.memoryUsed }
                append("total", name: deviceID == nil ? String(localized: "chart.gpu.total \(device.name)") : String(localized: "chart.swap.total"), reference: true) {
                    guard let total = $0.memoryTotal, total > 0 else { return nil }
                    return total
                }
            case .engines:
                let names = Set(points.flatMap { $0.gpuMetrics.filter { $0.id == device.id }.flatMap { $0.engines.keys } }).sorted()
                for name in names {
                    append(name, name: deviceID == nil ? "\(device.name) · \(name)" : name) { $0.engines[name] }
                }
            }
        }
        series = result
        switch metric {
        case .usage, .engines: yDomain = 0...100
        case .power, .memory:
            yDomain = 0...max(1, (result.flatMap(\.samples).map(\.value).max() ?? 0) * 1.1)
        }
    }

    var hasReadings: Bool { metric == .power ? !series.isEmpty : series.contains { !$0.isReference } }
}

nonisolated struct SystemGPUCharts: Sendable {
    let usage: GPUChartData
    let power: GPUChartData
    let memory: [GPUChartData]
    let engines: [GPUChartData]
    static let empty = SystemGPUCharts(dataPoints: [])

    init(dataPoints: [SystemDataPoint]) {
        usage = GPUChartData(metric: .usage, dataPoints: dataPoints)
        power = GPUChartData(metric: .power, dataPoints: dataPoints)
        let devices = GPUChartData.devices(in: dataPoints)
        memory = devices.map { GPUChartData(metric: .memory, dataPoints: dataPoints, deviceID: $0.id) }.filter(\.hasReadings)
        engines = devices.map { GPUChartData(metric: .engines, dataPoints: dataPoints, deviceID: $0.id) }.filter(\.hasReadings)
    }
}
