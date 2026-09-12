import SwiftUI
import Charts

// MARK: - Shared pieces

/// One named line on a GPU chart, sampled from the data points that reported it.
private struct GPUChartSeries: Identifiable {
    struct Sample: Identifiable {
        var id: Date { date }
        let date: Date
        let value: Double
    }

    let id: String
    let samples: [Sample]

    var latest: Double? { samples.last?.value }
}

/// Matches the header used by the other GPU / sensor cards.
private struct GPUChartCardLabel: View {
    let title: Text
    let subtitle: LocalizedStringKey
    let systemName: String?
    let isPinned: Bool
    let onPinToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                title.font(.headline)
                if systemName == nil {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let systemName {
                    Text(systemName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }
    }
}

/// Horizontal dot-and-label legend shared with the Temperature, GPU and Network Interfaces charts.
private struct GPUChartLegend: View {
    let names: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(names, id: \.self) { name in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(color(for: name, in: names))
                            .frame(width: 8, height: 8)
                        Text(name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 20)
    }
}

/// Multi-line chart shared by the power and engines cards.
private struct GPUSeriesLineChart: View {
    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.chartShowXGridLines) private var chartShowXGridLines

    let series: [GPUChartSeries]
    let xAxisFormat: Date.FormatStyle
    let yDomain: ClosedRange<Double>?
    let yLabel: (Double) -> String

    private var names: [String] { series.map(\.id) }

    var body: some View {
        Chart(series) { line in
            ForEach(line.samples) { sample in
                LineMark(
                    x: .value("Date", sample.date),
                    y: .value("Value", sample.value)
                )
                .foregroundStyle(by: .value("Series", line.id))
            }
        }
        .chartForegroundStyleScale { name in
            color(for: name, in: names)
        }
        .chartXAxis {
            AxisMarks(values: insetTickDates(for: chartXDomain)) { _ in
                if chartShowXGridLines {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    AxisTick()
                }
                AxisValueLabel(format: xAxisFormat, collisionResolution: .disabled)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(yLabel(number)).font(.caption2).padding(.trailing, 6)
                    }
                }
            }
        }
        .modifier(OptionalYScale(domain: yDomain))
        .chartLegend(.hidden)
        .chartXScaleIfNeeded(chartXDomain)
        .padding(.top, 5)
        .drawingGroup()
    }
}

private struct OptionalYScale: ViewModifier {
    let domain: ClosedRange<Double>?

    func body(content: Content) -> some View {
        if let domain {
            content.chartYScale(domain: domain)
        } else {
            content
        }
    }
}

private func formatWatts(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...1))) + " W"
}

// MARK: - GPU Power Draw

/// Average power consumption of every GPU, with a separate package line for
/// Intel GPUs that report one.
struct SystemGPUPowerChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var systemName: String? = nil

    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    private var series: [GPUChartSeries] {
        let names = Set(dataPoints.flatMap { $0.gpuMetrics.map(\.name) }).sorted()
        return names.flatMap { name -> [GPUChartSeries] in
            let gpuSamples = dataPoints.compactMap { point -> (GPUMetricPoint, Date)? in
                point.gpuMetrics.first(where: { $0.name == name }).map { ($0, point.date) }
            }
            let power = gpuSamples.compactMap { gpu, date in
                gpu.power.map { GPUChartSeries.Sample(date: date, value: $0) }
            }
            // The agent sends a 0 W package reading for GPUs without one; only chart real package draw.
            let packagePower = gpuSamples.compactMap { gpu, date in
                gpu.packagePower.map { GPUChartSeries.Sample(date: date, value: $0) }
            }
            var lines: [GPUChartSeries] = []
            if !power.isEmpty {
                lines.append(GPUChartSeries(id: name, samples: power))
            }
            if packagePower.contains(where: { $0.value > 0 }) {
                lines.append(GPUChartSeries(id: String(localized: "chart.gpuPower.package \(name)"), samples: packagePower))
            }
            return lines
        }
    }

    var body: some View {
        let series = series
        GroupBox(label: GPUChartCardLabel(
            title: Text("chart.gpuPower.title") + Text(" (W)"),
            subtitle: "chart.gpuPower.subtitle",
            systemName: systemName,
            isPinned: isPinned,
            onPinToggle: onPinToggle
        )) {
            VStack(spacing: 8) {
                GPUSeriesLineChart(
                    series: series,
                    xAxisFormat: xAxisFormat,
                    yDomain: nil,
                    yLabel: { adaptiveAxisLabel($0, domainMax: series.flatMap(\.samples).map(\.value).max() ?? 0) }
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("chart.gpuPower.title"))
                .accessibilityValue(accessibilityDescription(series))

                if !series.isEmpty {
                    GPUChartLegend(names: series.map(\.id))
                }
            }
            .frame(height: 220)
        }
    }

    private func accessibilityDescription(_ series: [GPUChartSeries]) -> String {
        series.compactMap { line in
            line.latest.map { "\(line.id): \(formatWatts($0))" }
        }.joined(separator: ", ")
    }
}

// MARK: - GPU Engines

/// Per-engine utilization (Render/3D, Video, …) for GPUs that report it.
struct SystemGPUEnginesChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var systemName: String? = nil

    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    private var series: [GPUChartSeries] {
        let gpuNames = Set(dataPoints.flatMap { $0.gpuMetrics.filter { !$0.engines.isEmpty }.map(\.name) }).sorted()
        return gpuNames.flatMap { name -> [GPUChartSeries] in
            let engineNames = Set(dataPoints.flatMap { point in
                point.gpuMetrics.first(where: { $0.name == name })?.engines.keys.map { $0 } ?? []
            }).sorted()
            return engineNames.map { engine in
                // Engine names only collide when several GPUs report engines.
                let label = gpuNames.count > 1 ? "\(name) · \(engine)" : engine
                let samples = dataPoints.compactMap { point -> GPUChartSeries.Sample? in
                    guard let value = point.gpuMetrics.first(where: { $0.name == name })?.engines[engine] else { return nil }
                    return GPUChartSeries.Sample(date: point.date, value: value)
                }
                return GPUChartSeries(id: label, samples: samples)
            }
        }
    }

    var body: some View {
        let series = series
        GroupBox(label: GPUChartCardLabel(
            title: Text("chart.gpuEngines.title") + Text(" (%)"),
            subtitle: "chart.gpuEngines.subtitle",
            systemName: systemName,
            isPinned: isPinned,
            onPinToggle: onPinToggle
        )) {
            VStack(spacing: 8) {
                GPUSeriesLineChart(
                    series: series,
                    xAxisFormat: xAxisFormat,
                    yDomain: nil,
                    yLabel: { String(format: "%.0f", $0) }
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("chart.gpuEngines.title"))
                .accessibilityValue(accessibilityDescription(series))

                if !series.isEmpty {
                    GPUChartLegend(names: series.map(\.id))
                }
            }
            .frame(height: 220)
        }
    }

    private func accessibilityDescription(_ series: [GPUChartSeries]) -> String {
        series.compactMap { line in
            line.latest.map { "\(line.id): \(String(format: "%.0f", $0))%" }
        }.joined(separator: ", ")
    }
}

// MARK: - GPU VRAM

/// Memory used by a single GPU against its total, like the swap chart.
struct SystemGPUMemoryChartView: View {
    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.chartShowXGridLines) private var chartShowXGridLines

    let gpuName: String
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var systemName: String? = nil

    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    private var samples: [GPUChartSeries.Sample] {
        dataPoints.compactMap { point in
            point.gpuMetrics.first(where: { $0.name == gpuName })?.memoryUsed.map {
                GPUChartSeries.Sample(date: point.date, value: $0 / unitDivisor)
            }
        }
    }

    /// Memory arrives in MB; the whole card switches to GB for cards with at least 1 GB of VRAM.
    private var totalMegabytes: Double {
        dataPoints.compactMap { $0.gpuMetrics.first(where: { $0.name == gpuName })?.memoryTotal }.max() ?? 0
    }

    private var usesGigabytes: Bool { totalMegabytes >= 1_024 }
    private var unitDivisor: Double { usesGigabytes ? 1_024 : 1 }
    private var unitLabel: String { usesGigabytes ? "GB" : "MB" }
    private var total: Double { totalMegabytes / unitDivisor }

    var body: some View {
        GroupBox(label: GPUChartCardLabel(
            title: Text(verbatim: "\(gpuName) VRAM") + Text(" (\(unitLabel))"),
            subtitle: "chart.gpuMemory.subtitle",
            systemName: systemName,
            isPinned: isPinned,
            onPinToggle: onPinToggle
        )) {
            VStack(spacing: 4) {
                chartBody
                    .frame(height: 185)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 8, height: 8)
                        Text("chart.gpuMemory.used").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(.gray.opacity(0.5))
                            .frame(width: 12, height: 1.5)
                        Text("chart.gpuMemory.total").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(verbatim: latestSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(height: 200)
        }
    }

    private var chartBody: some View {
        Chart {
            ForEach(samples) { sample in
                LineMark(
                    x: .value("Date", sample.date),
                    y: .value("Used", sample.value)
                )
                .foregroundStyle(.green)

                AreaMark(
                    x: .value("Date", sample.date),
                    yStart: .value("Type", 0),
                    yEnd: .value("Used", sample.value)
                )
                .foregroundStyle(LinearGradient(colors: [.green.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
            }
            if total > 0 {
                RuleMark(y: .value("Total", total))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
            }
        }
        .modifier(OptionalYScale(domain: total > 0 ? 0...total : nil))
        .chartXAxis {
            AxisMarks(values: insetTickDates(for: chartXDomain)) { _ in
                if chartShowXGridLines {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    AxisTick()
                }
                AxisValueLabel(format: xAxisFormat, collisionResolution: .disabled)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(adaptiveAxisLabel(number, domainMax: total)).font(.caption2).padding(.trailing, 6)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartXScaleIfNeeded(chartXDomain)
        .padding(.top, 5)
        .drawingGroup()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(gpuName) VRAM"))
        .accessibilityValue(latestSummary)
    }

    /// "1 GB / 24 GB" for the latest sample, in the same units as the memory widget.
    private var latestSummary: String {
        guard let used = dataPoints.last?.gpuMetrics.first(where: { $0.name == gpuName })?.memoryUsed else { return "" }
        return "\(MetricFormatter.memory(megabytes: used)) / \(MetricFormatter.memory(megabytes: totalMegabytes))"
    }
}
