import Charts
import SwiftUI
import WidgetKit

struct WidgetMetricChartView: View {
    @Environment(\.locale) private var locale
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: SimpleEntry
    var containerMetric: DockerWidgetMetric? = nil
    var containerName: String? = nil

    private var presentation: WidgetChartPresentation {
        if let containerMetric {
            return WidgetChartPresentation(
                containerMetric: containerMetric,
                points: entry.containerData.first?.statPoints ?? []
            )
        }
        return WidgetChartPresentation(
            chartType: entry.chartType,
            dataPoints: entry.dataPoints,
            containerData: entry.containerData
        )
    }

    private var title: Text {
        if let containerName {
            Text(verbatim: containerName)
        } else {
            Text(LocalizedStringKey(entry.chartType.titleKey))
        }
    }

    private var isLarge: Bool {
        widgetFamily == .systemLarge
    }

    var body: some View {
        let presentation = presentation

        VStack(alignment: .leading, spacing: isLarge ? 12 : 8) {
            header(for: presentation)

            if presentation.series.isEmpty {
                NoDataPlaceholderView(metricName: containerMetric?.title ?? entry.chartType.localizedTitle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if presentation.series.count > 1 {
                    legend(for: presentation)
                }

                chart(for: presentation)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)

                timeLabels(for: presentation)

                if isLarge {
                    summary(for: presentation)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue(for: presentation))
    }

    private func header(for presentation: WidgetChartPresentation) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: entry.chartType.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(presentation.primaryColor)
                .frame(width: 30, height: 30)
                .background(presentation.primaryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                .widgetAccentable()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(isLarge ? .headline : .subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 5) {
                    Text(entry.systemName)
                        .lineLimit(1)

                    Text("•")
                        .accessibilityHidden(true)

                    Text(containerMetric?.title ?? LocalizedStringResource(stringLiteral: entry.timeRange.rawValue))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    if entry.isFromCache {
                        Image(systemName: "clock.arrow.circlepath")
                            .accessibilityLabel("widget.cached")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(presentation.currentValue.map { presentation.valueFormat.format($0, locale: locale) } ?? "—")
                    .font(isLarge ? .title2.weight(.bold) : .headline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .widgetAccentable()

                if let referenceValue = presentation.referenceValue {
                    Text("/ \(presentation.valueFormat.format(referenceValue, locale: locale))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .layoutPriority(1)
        }
    }

    private func legend(for presentation: WidgetChartPresentation) -> some View {
        HStack(spacing: 10) {
            ForEach(Array(presentation.series.prefix(isLarge ? 4 : 3))) { series in
                HStack(spacing: 4) {
                    WidgetChartLegendLine()
                        .stroke(series.color, style: series.strokeStyle)
                        .frame(width: 28, height: 6)
                        .widgetAccentable()
                        .accessibilityHidden(true)

                    Text(series.name)
                        .lineLimit(1)
                }
            }

            if presentation.series.count > (isLarge ? 4 : 3) {
                Text("+\(presentation.series.count - (isLarge ? 4 : 3))")
            }

            Spacer(minLength: 0)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func chart(for presentation: WidgetChartPresentation) -> some View {
        Chart {
            ForEach(presentation.gridValues, id: \.self) { value in
                RuleMark(y: .value("Grid", value))
                    .foregroundStyle(Color.secondary.opacity(0.12))
                    .lineStyle(StrokeStyle(lineWidth: 0.5))
            }

            if let referenceValue = presentation.referenceValue {
                RuleMark(y: .value("Capacity", referenceValue))
                    .foregroundStyle(Color.secondary.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }

            ForEach(presentation.series) { series in
                if presentation.series.count == 1 {
                    ForEach(series.points) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Baseline", presentation.yDomain.lowerBound),
                            yEnd: .value("Value", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [series.color.opacity(0.3), series.color.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.monotone)
                    }
                }

                ForEach(series.points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value),
                        series: .value("Series", series.id)
                    )
                    .foregroundStyle(series.color)
                    .lineStyle(series.strokeStyle)
                    .interpolationMethod(.monotone)
                }

                if let latest = series.points.last {
                    PointMark(
                        x: .value("Latest date", latest.date),
                        y: .value("Latest value", latest.value)
                    )
                    .foregroundStyle(series.color)
                    .symbolSize(isLarge ? 24 : 18)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: presentation.xDomain)
        .chartYScale(domain: presentation.yDomain)
        .chartLegend(.hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(presentation.primaryColor.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .widgetAccentable()
        .accessibilityHidden(true)
    }

    private func timeLabels(for presentation: WidgetChartPresentation) -> some View {
        HStack {
            Text(presentation.xDomain.lowerBound, format: entry.timeRange.xAxisFormat)
            Spacer()
            Text(presentation.xDomain.upperBound, format: entry.timeRange.xAxisFormat)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .monospacedDigit()
    }

    private func summary(for presentation: WidgetChartPresentation) -> some View {
        HStack(spacing: 18) {
            WidgetChartStatistic(
                label: "widget.chart.average",
                value: presentation.averageValue.map { presentation.valueFormat.format($0, locale: locale) } ?? "—"
            )

            WidgetChartStatistic(
                label: "widget.chart.peak",
                value: presentation.peakValue.map { presentation.valueFormat.format($0, locale: locale) } ?? "—"
            )

            Spacer(minLength: 0)

            Text(entry.date, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func accessibilityValue(for presentation: WidgetChartPresentation) -> String {
        guard let currentValue = presentation.currentValue else {
            return String(localized: "widget.noData")
        }

        let metric = containerMetric.map { String(localized: $0.title) + ", " } ?? ""
        return "\(entry.systemName), \(metric)\(presentation.valueFormat.format(currentValue, locale: locale))"
    }
}

private struct WidgetChartLegendLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

private struct WidgetChartStatistic: View {
    let label: LocalizedStringResource
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}

private struct WidgetChartPoint: Identifiable {
    var id: Date { date }

    let date: Date
    let value: Double
}

private struct WidgetChartSeries: Identifiable {
    let id: String
    let name: String
    let colorIndex: Int
    let points: [WidgetChartPoint]

    var color: Color {
        Self.palette[colorIndex % Self.palette.count]
    }

    var strokeStyle: StrokeStyle {
        switch colorIndex % 4 {
        case 1:
            return StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [6, 3])
        case 2:
            return StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [2, 3])
        case 3:
            return StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [8, 3, 2, 3])
        default:
            return StrokeStyle(lineWidth: 2.25, lineCap: .round, lineJoin: .round)
        }
    }

    private static let palette: [Color] = [
        .blue, .green, .orange, .purple, .pink, .teal, .indigo, .red, .cyan, .mint
    ]
}

private enum WidgetChartValueFormat {
    case percent
    case temperature
    case bytesPerSecond
    case bytes
    case gigabytes
    case megabytes
    case milliseconds
    case decimal

    func format(_ value: Double, locale: Locale) -> String {
        switch self {
        case .percent:
            return MetricFormatter.percent(value, locale: locale)
        case .temperature:
            return value.formatted(
                .number.locale(locale).precision(.fractionLength(0...1))
            ) + "°C"
        case .bytesPerSecond:
            return MetricFormatter.throughput(bytesPerSecond: value)
        case .bytes:
            return ByteCountFormatter.string(fromByteCount: Int64(value.rounded()), countStyle: .decimal)
        case .gigabytes:
            if value >= 1_024 {
                return (value / 1_024).formatted(
                    .number.locale(locale).precision(.fractionLength(0...1))
                ) + " TB"
            }
            return value.formatted(
                .number.locale(locale).precision(.fractionLength(0...1))
            ) + " GB"
        case .megabytes:
            return MetricFormatter.memory(megabytes: value)
        case .milliseconds:
            return value.formatted(
                .number.locale(locale).precision(.fractionLength(0...1))
            ) + " ms"
        case .decimal:
            return value.formatted(
                .number.locale(locale).precision(.fractionLength(0...2))
            )
        }
    }
}

private struct WidgetChartPresentation {
    let series: [WidgetChartSeries]
    let summaryPoints: [WidgetChartPoint]
    let valueFormat: WidgetChartValueFormat
    let fixedYDomain: ClosedRange<Double>?
    let referenceValue: Double?

    var primaryColor: Color {
        series.first?.color ?? .accentColor
    }

    var currentValue: Double? {
        summaryPoints.last?.value
    }

    var averageValue: Double? {
        guard !summaryPoints.isEmpty else { return nil }
        return summaryPoints.map(\.value).reduce(0, +) / Double(summaryPoints.count)
    }

    var peakValue: Double? {
        summaryPoints.map(\.value).max()
    }

    var xDomain: ClosedRange<Date> {
        let dates = series.flatMap(\.points).map(\.date)
        let lowerBound = dates.min() ?? .now.addingTimeInterval(-3_600)
        let upperBound = dates.max() ?? .now
        guard lowerBound < upperBound else {
            return lowerBound...lowerBound.addingTimeInterval(60)
        }
        return lowerBound...upperBound
    }

    var yDomain: ClosedRange<Double> {
        if let fixedYDomain {
            return fixedYDomain
        }

        let values = series.flatMap(\.points).map(\.value)
        guard let maximum = values.max(), let minimum = values.min() else {
            return 0...1
        }

        if let referenceValue {
            return 0...max(referenceValue, max(maximum * 1.08, 1))
        }

        if minimum >= 0 {
            return 0...max(maximum * 1.12, 1)
        }

        let span = max(maximum - minimum, 1)
        return (minimum - span * 0.08)...(maximum + span * 0.08)
    }

    var gridValues: [Double] {
        let span = yDomain.upperBound - yDomain.lowerBound
        return [0.25, 0.5, 0.75].map { yDomain.lowerBound + span * $0 }
    }

    init(containerMetric: DockerWidgetMetric, points: [StatPoint]) {
        let points = points.sorted { $0.date < $1.date }
        switch containerMetric {
        case .cpu, .memory:
            let values = points.map {
                WidgetChartPoint(date: $0.date, value: containerMetric == .cpu ? $0.cpu : $0.memory)
            }
            series = values.isEmpty ? [] : [WidgetChartSeries(
                id: containerMetric.rawValue, name: String(localized: containerMetric.title),
                colorIndex: 0, points: values
            )]
            summaryPoints = values
            valueFormat = containerMetric == .cpu ? .percent : .megabytes
        case .network:
            let download = points.map { WidgetChartPoint(date: $0.date, value: $0.netReceived) }
            let upload = points.map { WidgetChartPoint(date: $0.date, value: $0.netSent) }
            series = points.isEmpty ? [] : [
                WidgetChartSeries(
                    id: "download", name: String(localized: "chart.bandwidth.download"),
                    colorIndex: 0, points: download
                ),
                WidgetChartSeries(
                    id: "upload", name: String(localized: "chart.bandwidth.upload"),
                    colorIndex: 1, points: upload
                )
            ]
            summaryPoints = points.map {
                WidgetChartPoint(date: $0.date, value: $0.netReceived + $0.netSent)
            }
            valueFormat = .bytesPerSecond
        }
        fixedYDomain = nil
        referenceValue = nil
    }

    init(
        chartType: WidgetChartType,
        dataPoints: [SystemDataPoint],
        containerData: [ProcessedContainerData]
    ) {
        let dataPoints = dataPoints.sorted { $0.date < $1.date }
        var series: [WidgetChartSeries] = []
        var summaryPoints: [WidgetChartPoint] = []
        var valueFormat = WidgetChartValueFormat.decimal
        var fixedYDomain: ClosedRange<Double>?
        var referenceValue: Double?

        switch chartType {
        case .systemInfo:
            break

        case .systemCPU:
            series = Self.systemSeries(name: "CPU", dataPoints: dataPoints) { $0.cpu }
            summaryPoints = series.first?.points ?? []
            valueFormat = .percent
            fixedYDomain = 0...100

        case .systemCPUTimeBreakdown:
            let categories: [(String, Int)] = [
                (String(localized: "chart.cpu.breakdown.user"), 0),
                (String(localized: "chart.cpu.breakdown.system"), 1),
                (String(localized: "chart.cpu.breakdown.iowait"), 2),
                (String(localized: "chart.cpu.breakdown.steal"), 3)
            ]
            series = categories.enumerated().compactMap { colorIndex, category in
                Self.systemSeries(
                    name: category.0,
                    colorIndex: colorIndex,
                    dataPoints: dataPoints
                ) { point in
                    guard let breakdown = point.cpuBreakdown, breakdown.indices.contains(category.1) else {
                        return nil
                    }
                    return breakdown[category.1]
                }.first
            }
            summaryPoints = Self.systemPoints(dataPoints) { $0.cpu }
            valueFormat = .percent
            fixedYDomain = 0...100

        case .systemCPUCores:
            let coreCount = dataPoints.compactMap { $0.cpuPerCore?.count }.max() ?? 0
            series = Self.limitSeries(
                (0..<coreCount).compactMap { coreIndex in
                    Self.systemSeries(
                        name: "CPU \(coreIndex + 1)",
                        colorIndex: coreIndex,
                        dataPoints: dataPoints
                    ) { point in
                        guard let cores = point.cpuPerCore, cores.indices.contains(coreIndex) else {
                            return nil
                        }
                        return cores[coreIndex]
                    }.first
                }
            )
            summaryPoints = Self.systemPoints(dataPoints) { point in
                guard let cores = point.cpuPerCore, !cores.isEmpty else { return nil }
                return cores.reduce(0, +) / Double(cores.count)
            }
            valueFormat = .percent
            fixedYDomain = 0...100

        case .systemMemory:
            series = Self.systemSeries(name: String(localized: "Memory"), dataPoints: dataPoints) {
                $0.memoryPercent
            }
            summaryPoints = series.first?.points ?? []
            valueFormat = .percent
            fixedYDomain = 0...100

        case .systemTemperature:
            series = Self.namedSystemSeries(
                names: Set(dataPoints.flatMap { $0.temperatures.map(\.name) }),
                dataPoints: dataPoints
            ) { point, name in
                point.temperatures.first(where: { $0.name == name })?.value
            }
            summaryPoints = Self.systemPoints(dataPoints) { point in
                point.temperatures.map(\.value).max()
            }
            valueFormat = .temperature

        case .systemDiskUsage:
            series = Self.systemSeries(name: String(localized: "chart.disk.used"), dataPoints: dataPoints) {
                $0.diskUsage?.used
            }
            summaryPoints = series.first?.points ?? []
            valueFormat = .gigabytes
            referenceValue = dataPoints.compactMap { $0.diskUsage?.total }.max()

        case .systemDiskIO:
            series = Self.pairedSystemSeries(
                firstName: String(localized: "chart.diskIO.read"),
                secondName: String(localized: "chart.diskIO.write"),
                dataPoints: dataPoints,
                firstValue: { $0.diskIO?.read },
                secondValue: { $0.diskIO?.write }
            )
            summaryPoints = Self.systemPoints(dataPoints) { point in
                point.diskIO.map { $0.read + $0.write }
            }
            valueFormat = .bytesPerSecond

        case .systemDiskIOUtilization:
            series = Self.systemSeries(name: String(localized: "Util"), dataPoints: dataPoints) {
                $0.diskIOStats?.utilPct
            }
            summaryPoints = series.first?.points ?? []
            valueFormat = .percent
            fixedYDomain = 0...100

        case .systemDiskIOTimes:
            series = Self.pairedSystemSeries(
                firstName: String(localized: "chart.diskIO.readTime"),
                secondName: String(localized: "chart.diskIO.writeTime"),
                dataPoints: dataPoints,
                firstValue: { $0.diskIOStats?.readTimePct },
                secondValue: { $0.diskIOStats?.writeTimePct }
            )
            summaryPoints = Self.systemPoints(dataPoints) { point in
                point.diskIOStats.map { max($0.readTimePct, $0.writeTimePct) }
            }
            valueFormat = .percent
            fixedYDomain = 0...100

        case .systemDiskAwait:
            series = Self.pairedSystemSeries(
                firstName: String(localized: "chart.diskIO.rAwait"),
                secondName: String(localized: "chart.diskIO.wAwait"),
                dataPoints: dataPoints,
                firstValue: { $0.diskIOStats?.rAwait },
                secondValue: { $0.diskIOStats?.wAwait }
            )
            summaryPoints = Self.systemPoints(dataPoints) { point in
                point.diskIOStats.map { max($0.rAwait, $0.wAwait) }
            }
            valueFormat = .milliseconds

        case .systemDiskIOQueueDepth:
            series = Self.systemSeries(name: String(localized: "Value"), dataPoints: dataPoints) {
                $0.diskIOStats?.weightedIO
            }
            summaryPoints = series.first?.points ?? []

        case .systemBandwidth:
            series = Self.pairedSystemSeries(
                firstName: String(localized: "chart.bandwidth.download"),
                secondName: String(localized: "chart.bandwidth.upload"),
                dataPoints: dataPoints,
                firstValue: { $0.bandwidth?.download },
                secondValue: { $0.bandwidth?.upload }
            )
            summaryPoints = Self.systemPoints(dataPoints) { point in
                point.bandwidth.map { $0.download + $0.upload }
            }
            valueFormat = .bytesPerSecond

        case .systemBandwidthDownload:
            series = Self.interfaceSeries(dataPoints: dataPoints, value: \.received)
            summaryPoints = Self.sumSeriesByDate(series)
            valueFormat = .bytesPerSecond

        case .systemBandwidthUpload:
            series = Self.interfaceSeries(dataPoints: dataPoints, value: \.sent)
            summaryPoints = Self.sumSeriesByDate(series)
            valueFormat = .bytesPerSecond

        case .systemBandwidthCumulativeDownload:
            series = Self.cumulativeInterfaceSeries(
                dataPoints: dataPoints,
                total: \.totalReceived,
                rate: \.received
            )
            summaryPoints = Self.sumSeriesByDate(series)
            valueFormat = .bytes

        case .systemBandwidthCumulativeUpload:
            series = Self.cumulativeInterfaceSeries(
                dataPoints: dataPoints,
                total: \.totalSent,
                rate: \.sent
            )
            summaryPoints = Self.sumSeriesByDate(series)
            valueFormat = .bytes

        case .systemLoadAverage:
            series = [
                Self.systemSeries(name: String(localized: "chart.load.1min"), colorIndex: 0, dataPoints: dataPoints) { $0.loadAverage?.l1 }.first,
                Self.systemSeries(name: String(localized: "chart.load.5min"), colorIndex: 1, dataPoints: dataPoints) { $0.loadAverage?.l5 }.first,
                Self.systemSeries(name: String(localized: "chart.load.15min"), colorIndex: 2, dataPoints: dataPoints) { $0.loadAverage?.l15 }.first
            ].compactMap { $0 }
            summaryPoints = series.first?.points ?? []

        case .systemSwap:
            series = Self.systemSeries(name: String(localized: "chart.swap.used"), dataPoints: dataPoints) {
                $0.swap?.used
            }
            summaryPoints = series.first?.points ?? []
            valueFormat = .gigabytes
            referenceValue = dataPoints.compactMap { $0.swap?.total }.max()

        case .systemGPU:
            series = Self.namedSystemSeries(
                names: Set(dataPoints.flatMap { $0.gpuMetrics.map(\.name) }),
                dataPoints: dataPoints
            ) { point, name in
                point.gpuMetrics.first(where: { $0.name == name })?.usage
            }
            summaryPoints = Self.maxSeriesByDate(series)
            valueFormat = .percent
            fixedYDomain = 0...100

        case .systemNetworkInterfaces:
            series = Self.namedSystemSeries(
                names: Set(dataPoints.flatMap { $0.networkInterfaces.map(\.name) }),
                dataPoints: dataPoints
            ) { point, name in
                point.networkInterfaces.first(where: { $0.name == name }).map { $0.sent + $0.received }
            }
            summaryPoints = Self.sumSeriesByDate(series)
            valueFormat = .bytesPerSecond

        case .extraDiskUsage:
            series = Self.namedSystemSeries(
                names: Set(dataPoints.flatMap { $0.extraFilesystems.map(\.name) }),
                dataPoints: dataPoints
            ) { point, name in
                point.extraFilesystems.first(where: { $0.name == name })?.percent
            }
            summaryPoints = Self.maxSeriesByDate(series)
            valueFormat = .percent
            fixedYDomain = 0...100

        case .extraDiskIO:
            series = Self.pairedSystemSeries(
                firstName: String(localized: "chart.diskIO.read"),
                secondName: String(localized: "chart.diskIO.write"),
                dataPoints: dataPoints,
                firstValue: { point in
                    Self.sum(point.extraFilesystems.compactMap(\.diskRead))
                },
                secondValue: { point in
                    Self.sum(point.extraFilesystems.compactMap(\.diskWrite))
                }
            )
            summaryPoints = Self.sumSeriesByDate(series)
            valueFormat = .bytesPerSecond

        case .extraDiskIOUtilization:
            series = Self.extraDiskSeries(dataPoints: dataPoints) { $0.diskIOStats?.utilPct }
            summaryPoints = Self.maxSeriesByDate(series)
            valueFormat = .percent
            fixedYDomain = 0...100

        case .extraDiskIOTimes:
            series = Self.pairedSystemSeries(
                firstName: String(localized: "chart.diskIO.readTime"),
                secondName: String(localized: "chart.diskIO.writeTime"),
                dataPoints: dataPoints,
                firstValue: { point in
                    point.extraFilesystems.compactMap { $0.diskIOStats?.readTimePct }.max()
                },
                secondValue: { point in
                    point.extraFilesystems.compactMap { $0.diskIOStats?.writeTimePct }.max()
                }
            )
            summaryPoints = Self.maxSeriesByDate(series)
            valueFormat = .percent
            fixedYDomain = 0...100

        case .extraDiskAwait:
            series = Self.pairedSystemSeries(
                firstName: String(localized: "chart.diskIO.rAwait"),
                secondName: String(localized: "chart.diskIO.wAwait"),
                dataPoints: dataPoints,
                firstValue: { point in
                    point.extraFilesystems.compactMap { $0.diskIOStats?.rAwait }.max()
                },
                secondValue: { point in
                    point.extraFilesystems.compactMap { $0.diskIOStats?.wAwait }.max()
                }
            )
            summaryPoints = Self.maxSeriesByDate(series)
            valueFormat = .milliseconds

        case .extraDiskIOQueueDepth:
            series = Self.extraDiskSeries(dataPoints: dataPoints) { $0.diskIOStats?.weightedIO }
            summaryPoints = Self.maxSeriesByDate(series)

        case .containerCPU:
            series = Self.containerSeries(containerData: containerData, value: \.cpu)
            summaryPoints = Self.sumSeriesByDate(series)
            valueFormat = .percent

        case .containerMemory:
            series = Self.containerSeries(containerData: containerData, value: \.memory)
            summaryPoints = Self.sumSeriesByDate(series)
            valueFormat = .megabytes

        case .containerNetwork:
            series = Self.containerSeries(containerData: containerData) { point in
                point.netSent + point.netReceived
            }
            summaryPoints = Self.sumSeriesByDate(series)
            valueFormat = .bytesPerSecond
        }

        self.series = series.filter { !$0.points.isEmpty }
        self.summaryPoints = summaryPoints.sorted { $0.date < $1.date }
        self.valueFormat = valueFormat
        self.fixedYDomain = fixedYDomain
        self.referenceValue = referenceValue
    }

    private static func systemSeries(
        name: String,
        colorIndex: Int = 0,
        dataPoints: [SystemDataPoint],
        value: (SystemDataPoint) -> Double?
    ) -> [WidgetChartSeries] {
        let points = systemPoints(dataPoints, value: value)
        guard !points.isEmpty else { return [] }
        return [WidgetChartSeries(id: name, name: name, colorIndex: colorIndex, points: points)]
    }

    private static func pairedSystemSeries(
        firstName: String,
        secondName: String,
        dataPoints: [SystemDataPoint],
        firstValue: (SystemDataPoint) -> Double?,
        secondValue: (SystemDataPoint) -> Double?
    ) -> [WidgetChartSeries] {
        systemSeries(name: firstName, colorIndex: 0, dataPoints: dataPoints, value: firstValue)
            + systemSeries(name: secondName, colorIndex: 1, dataPoints: dataPoints, value: secondValue)
    }

    private static func systemPoints(
        _ dataPoints: [SystemDataPoint],
        value: (SystemDataPoint) -> Double?
    ) -> [WidgetChartPoint] {
        dataPoints.compactMap { point in
            value(point).map { WidgetChartPoint(date: point.date, value: $0) }
        }
    }

    private static func namedSystemSeries(
        names: Set<String>,
        dataPoints: [SystemDataPoint],
        value: (SystemDataPoint, String) -> Double?
    ) -> [WidgetChartSeries] {
        let allSeries = names.sorted().enumerated().compactMap { colorIndex, name in
            systemSeries(name: name, colorIndex: colorIndex, dataPoints: dataPoints) {
                value($0, name)
            }.first
        }
        return limitSeries(allSeries)
    }

    private static func interfaceSeries(
        dataPoints: [SystemDataPoint],
        value: KeyPath<NetworkInterfacePoint, Double>
    ) -> [WidgetChartSeries] {
        namedSystemSeries(
            names: Set(dataPoints.flatMap { $0.networkInterfaces.map(\.name) }),
            dataPoints: dataPoints
        ) { point, name in
            point.networkInterfaces.first(where: { $0.name == name })?[keyPath: value]
        }
    }

    private static func cumulativeInterfaceSeries(
        dataPoints: [SystemDataPoint],
        total: KeyPath<NetworkInterfacePoint, Double?>,
        rate: KeyPath<NetworkInterfacePoint, Double>
    ) -> [WidgetChartSeries] {
        let names = Set(dataPoints.flatMap { $0.networkInterfaces.map(\.name) }).sorted()
        let allSeries = names.enumerated().compactMap { colorIndex, name -> WidgetChartSeries? in
            let interfacePoints = dataPoints.compactMap { point -> (Date, NetworkInterfacePoint)? in
                guard let interface = point.networkInterfaces.first(where: { $0.name == name }) else {
                    return nil
                }
                return (point.date, interface)
            }

            let hasTotals = interfacePoints.contains { ($0.1[keyPath: total] ?? 0) > 0 }
            var accumulated = 0.0
            var previousDate: Date?
            let points = interfacePoints.compactMap { date, interface -> WidgetChartPoint? in
                if hasTotals {
                    guard let value = interface[keyPath: total], value > 0 else { return nil }
                    return WidgetChartPoint(date: date, value: value)
                }

                let interval = previousDate.map { max(0, date.timeIntervalSince($0)) } ?? 60
                accumulated += interface[keyPath: rate] * interval
                previousDate = date
                return WidgetChartPoint(date: date, value: accumulated)
            }

            guard !points.isEmpty else { return nil }
            return WidgetChartSeries(id: name, name: name, colorIndex: colorIndex, points: points)
        }
        return limitSeries(allSeries)
    }

    private static func extraDiskSeries(
        dataPoints: [SystemDataPoint],
        value: (ExtraFilesystemPoint) -> Double?
    ) -> [WidgetChartSeries] {
        namedSystemSeries(
            names: Set(dataPoints.flatMap { $0.extraFilesystems.map(\.name) }),
            dataPoints: dataPoints
        ) { point, name in
            guard let disk = point.extraFilesystems.first(where: { $0.name == name }) else {
                return nil
            }
            return value(disk)
        }
    }

    private static func containerSeries(
        containerData: [ProcessedContainerData],
        value: KeyPath<StatPoint, Double>
    ) -> [WidgetChartSeries] {
        containerSeries(containerData: containerData) { $0[keyPath: value] }
    }

    private static func containerSeries(
        containerData: [ProcessedContainerData],
        value: (StatPoint) -> Double
    ) -> [WidgetChartSeries] {
        let allSeries = containerData.enumerated().map { colorIndex, container in
            WidgetChartSeries(
                id: container.id,
                name: container.name,
                colorIndex: colorIndex,
                points: container.statPoints
                    .sorted { $0.date < $1.date }
                    .map { WidgetChartPoint(date: $0.date, value: value($0)) }
            )
        }
        return limitSeries(allSeries)
    }

    private static func limitSeries(
        _ series: [WidgetChartSeries],
        limit: Int = 5
    ) -> [WidgetChartSeries] {
        let selected = series
            .sorted { ($0.points.map(\.value).max() ?? 0) > ($1.points.map(\.value).max() ?? 0) }
            .prefix(limit)

        return selected.enumerated().map { colorIndex, series in
            WidgetChartSeries(
                id: series.id,
                name: series.name,
                colorIndex: colorIndex,
                points: series.points
            )
        }
    }

    private static func sumSeriesByDate(_ series: [WidgetChartSeries]) -> [WidgetChartPoint] {
        combineSeriesByDate(series, initialValue: 0, combine: +)
    }

    private static func maxSeriesByDate(_ series: [WidgetChartSeries]) -> [WidgetChartPoint] {
        combineSeriesByDate(series, initialValue: -.infinity, combine: max)
    }

    private static func combineSeriesByDate(
        _ series: [WidgetChartSeries],
        initialValue: Double,
        combine: (Double, Double) -> Double
    ) -> [WidgetChartPoint] {
        var valuesByDate: [Date: Double] = [:]
        for point in series.flatMap(\.points) {
            valuesByDate[point.date] = combine(valuesByDate[point.date] ?? initialValue, point.value)
        }
        return valuesByDate
            .map { WidgetChartPoint(date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private static func sum(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +)
    }
}
