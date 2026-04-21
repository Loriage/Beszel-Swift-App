import SwiftUI
import Charts

private let breakdownOrder = ["other", "idle", "steal", "iowait", "user", "system"]

private struct CpuBreakdownSample: Identifiable {
    let id = UUID()
    let date: Date
    let category: String
    let yStart: Double
    let yEnd: Double
}

private func buildBreakdownSamples(from dataPoints: [SystemDataPoint]) -> [CpuBreakdownSample] {
    var result: [CpuBreakdownSample] = []
    for point in dataPoints {
        guard let breakdown = point.cpuBreakdown, breakdown.count >= 5 else { continue }
        let user   = breakdown[0]
        let system = breakdown[1]
        let iowait = breakdown[2]
        let steal  = breakdown[3]
        let idle   = breakdown[4]
        let other  = max(0.0, 100.0 - user - system - iowait - steal - idle)
        let values: [String: Double] = [
            "idle": idle, "other": other, "steal": steal,
            "iowait": iowait, "user": user, "system": system
        ]
        var y = 0.0
        for cat in breakdownOrder {
            let v = values[cat] ?? 0
            result.append(CpuBreakdownSample(date: point.date, category: cat, yStart: y, yEnd: y + v))
            y += v
        }
    }
    return result
}

struct SystemCpuTimeBreakdownChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.chartShowXGridLines) private var chartShowXGridLines

    private var samples: [CpuBreakdownSample] { buildBreakdownSamples(from: dataPoints) }

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("chart.cpu.breakdown.title") + Text(" (%)"))
                    .font(.headline)
                if systemName == nil {
                    Text("chart.cpu.breakdown.subtitle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let systemName = systemName {
                    Text(systemName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            VStack(spacing: 4) {
                Chart(samples) { sample in
                    AreaMark(
                        x: .value("Date", sample.date),
                        yStart: .value("", sample.yStart),
                        yEnd: .value("", sample.yEnd)
                    )
                    .foregroundStyle(by: .value("Category", sample.category))
                    .interpolationMethod(.monotone)
                }
                .chartForegroundStyleScale(domain: breakdownOrder, range: gradientRange(for: breakdownOrder))
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: insetTickDates(for: chartXDomain)) { value in
                    if chartShowXGridLines {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    }
                    AxisValueLabel(anchor: value.edgeAnchor, collisionResolution: .disabled) {
                        if let date = value.as(Date.self) {
                            compactXAxisLabel(for: date, xAxisFormat: xAxisFormat, xDomain: chartXDomain, index: value.index)
                        }
                    }
                }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0f", v)).font(.caption2).padding(.trailing, 6)
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartXScaleIfNeeded(chartXDomain)
                .padding(.top, 5)
                .frame(height: 185)
                .drawingGroup()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(breakdownOrder.reversed(), id: \.self) { cat in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(color(for: cat, in: breakdownOrder))
                                    .frame(width: 8, height: 8)
                                Text(LocalizedStringResource(stringLiteral: "chart.cpu.breakdown.\(cat)"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .frame(height: 200)
        }
    }
}

private struct PerCoreSample: Identifiable {
    let id = UUID()
    let date: Date
    let coreName: String
    let yStart: Double
    let yEnd: Double
}

struct SystemCpuCoresChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.chartShowXGridLines) private var chartShowXGridLines

    private var coreNames: [String] {
        guard let first = dataPoints.first, let cores = first.cpuPerCore else { return [] }
        return (0..<cores.count).map { "CPU \($0)" }
    }

    private var samples: [PerCoreSample] {
        let names = coreNames
        guard !names.isEmpty else { return [] }
        var result: [PerCoreSample] = []
        for point in dataPoints {
            guard let cores = point.cpuPerCore, cores.count == names.count else { continue }
            var y = 0.0
            for (i, val) in cores.enumerated() {
                result.append(PerCoreSample(date: point.date, coreName: names[i], yStart: y, yEnd: y + val))
                y += val
            }
        }
        return result
    }

    var body: some View {
        let names = coreNames
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("chart.cpu.cores.title") + Text(" (%)"))
                    .font(.headline)
                if systemName == nil {
                    Text("chart.cpu.cores.subtitle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let systemName = systemName {
                    Text(systemName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            VStack(spacing: 4) {
                Chart(samples) { sample in
                    AreaMark(
                        x: .value("Date", sample.date),
                        yStart: .value("", sample.yStart),
                        yEnd: .value("", sample.yEnd)
                    )
                    .foregroundStyle(by: .value("Core", sample.coreName))
                    .interpolationMethod(.monotone)
                }
                .chartForegroundStyleScale(domain: names, range: gradientRange(for: names))
                .chartXAxis {
                    AxisMarks(values: insetTickDates(for: chartXDomain)) { value in
                    if chartShowXGridLines {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    }
                    AxisValueLabel(anchor: value.edgeAnchor, collisionResolution: .disabled) {
                        if let date = value.as(Date.self) {
                            compactXAxisLabel(for: date, xAxisFormat: xAxisFormat, xDomain: chartXDomain, index: value.index)
                        }
                    }
                }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0f", v)).font(.caption2).padding(.trailing, 6)
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartXScaleIfNeeded(chartXDomain)
                .padding(.top, 5)
                .frame(height: 185)
                .drawingGroup()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(color(for: name, in: names))
                                    .frame(width: 8, height: 8)
                                Text(name).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .frame(height: 200)
        }
    }
}
