import Foundation

nonisolated enum SensorHistoryMetric: Sendable {
    case battery
    case fans

    var title: LocalizedStringResource {
        switch self {
        case .battery: "chart.battery.title"
        case .fans: "chart.fans.title"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .battery: "chart.battery.subtitle"
        case .fans: "chart.fans.subtitle"
        }
    }

    var pinnedItem: PinnedItem {
        switch self {
        case .battery: .systemBattery
        case .fans: .systemFans
        }
    }

    func validValue(_ value: Double) -> Double? {
        guard value.isFinite, value >= 0, self != .battery || value <= 100 else { return nil }
        return value
    }

    func formatted(_ value: Double, locale: Locale = .current) -> String {
        switch self {
        case .battery: (value / 100).formatted(.percent.locale(locale).precision(.fractionLength(0...1)))
        case .fans:
            String(localized: LocalizedStringResource(
                "chart.fans.rpm \(value.formatted(.number.locale(locale).precision(.fractionLength(0))))", locale: locale
            ))
        }
    }

    func averageReadings(_ samples: [[String: Double]]) -> [String: Double] {
        var totals: [String: (sum: Double, count: Int)] = [:]
        for sample in samples {
            for (name, value) in sample where validValue(value) != nil {
                let previous = totals[name] ?? (0, 0)
                totals[name] = (previous.sum + value, previous.count + 1)
            }
        }
        return totals.mapValues { $0.sum / Double($0.count) }
    }
}

nonisolated struct SensorChartSample: Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let value: Double
    // A missing reading breaks the line instead of connecting unrelated samples.
    let segment: Int
}

nonisolated struct SensorChartSeries: Identifiable, Sendable {
    let id: String
    let name: String?
    let styleIndex: Int
    let samples: [SensorChartSample]
    let currentValue: Double?
}

/// Prepared once when history changes, shared by the app and widget renderer.
nonisolated struct SensorChartData: Sendable {
    let metric: SensorHistoryMetric
    let series: [SensorChartSeries]
    let summary: [SensorChartSample]
    let latestDate: Date?
    let yDomain: ClosedRange<Double>

    var currentValue: Double? {
        summary.last.flatMap { $0.date == latestDate ? $0.value : nil }
    }

    init(metric: SensorHistoryMetric, dataPoints: [SystemDataPoint]) {
        self.metric = metric
        let points = dataPoints.sorted { $0.date < $1.date }
        latestDate = points.last?.date
        let names = Set(points.flatMap { point in
            let readings = metric == .battery ? point.batteries : point.fans
            return readings.filter { metric.validValue($0.value) != nil }.keys
        }).sorted()

        // Named batteries supersede the representative legacy `bat` reading.
        let legacyBattery = metric == .battery && names.isEmpty
        let sensorNames: [String?] = legacyBattery ? [nil] : names.map { $0 }
        series = sensorNames.enumerated().compactMap { index, name in
            let samples = Self.samples(points) { point in
                let value: Double?
                if let name {
                    value = (metric == .battery ? point.batteries : point.fans)[name]
                } else {
                    value = point.batteryPercent
                }
                return value.flatMap(metric.validValue)
            }
            guard !samples.isEmpty else { return nil }
            return SensorChartSeries(
                id: name ?? "battery.legacy", name: name, styleIndex: index, samples: samples,
                currentValue: samples.last.flatMap { $0.date == points.last?.date ? $0.value : nil }
            )
        }
        summary = Self.samples(points) { point in
            if legacyBattery { return point.batteryPercent.flatMap(metric.validValue) }
            let values = (metric == .battery ? point.batteries : point.fans).values.compactMap(metric.validValue)
            // Use the lowest charge / fastest fan for a useful multi-sensor glance.
            return metric == .battery ? values.min() : values.max()
        }
        yDomain = metric == .battery ? 0...100 : 0...max(1, (series.flatMap(\.samples).map(\.value).max() ?? 0) * 1.1)
    }

    private static func samples(
        _ points: [SystemDataPoint], value: (SystemDataPoint) -> Double?
    ) -> [SensorChartSample] {
        var segment = 0
        return points.compactMap { point in
            guard let value = value(point) else {
                segment += 1
                return nil
            }
            return SensorChartSample(date: point.date, value: value, segment: segment)
        }
    }
}

nonisolated struct SystemSensorCharts: Sendable {
    let battery: SensorChartData
    let fans: SensorChartData

    static let empty = SystemSensorCharts(dataPoints: [])

    init(dataPoints: [SystemDataPoint]) {
        battery = SensorChartData(metric: .battery, dataPoints: dataPoints)
        fans = SensorChartData(metric: .fans, dataPoints: dataPoints)
    }
}
