import SwiftUI
import Charts

struct ExtraDiskIOUtilizationChartView: View {
    let diskName: String
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.chartShowXGridLines) private var chartShowXGridLines

    private var maxUtil: Double {
        dataPoints.compactMap { $0.extraFilesystems.first(where: { $0.name == diskName })?.diskIOStats?.utilPct }.max() ?? 0
    }

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("\(diskName) \(LocalizedStringResource("chart.diskIO.utilization"))") + Text(" (%)"))
                    .font(.headline)
                if systemName == nil {
                    Text("chart.diskIO.utilization.subtitle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let systemName = systemName {
                    Text(systemName).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            Chart(dataPoints) { point in
                let util = point.extraFilesystems.first(where: { $0.name == diskName })?.diskIOStats?.utilPct ?? 0
                LineMark(x: .value("Date", point.date), y: .value("Util", util))
                    .foregroundStyle(.purple)
                AreaMark(x: .value("Date", point.date), yStart: .value("", 0), yEnd: .value("Util", util))
                    .foregroundStyle(LinearGradient(colors: [.purple.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
            }
            .chartYScale(domain: 0...min(niceYDomain(maxVal: Swift.max(maxUtil, 1)).max, 100))
            .chartXAxis { AxisMarks(values: insetTickDates(for: chartXDomain)) { value in
                    if chartShowXGridLines {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    }
                    AxisValueLabel(anchor: value.edgeAnchor, collisionResolution: .disabled) {
                        if let date = value.as(Date.self) {
                            compactXAxisLabel(for: date, xAxisFormat: xAxisFormat, xDomain: chartXDomain, index: value.index)
                        }
                    }
                } }
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
            .frame(height: 200)
            .drawingGroup()
        }
    }
}

struct ExtraDiskIOTimesChartView: View {
    let diskName: String
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.chartShowXGridLines) private var chartShowXGridLines

    private var maxTime: Double {
        dataPoints.compactMap { $0.extraFilesystems.first(where: { $0.name == diskName })?.diskIOStats }
            .flatMap { [$0.readTimePct, $0.writeTimePct] }.max() ?? 0
    }

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("\(diskName) \(LocalizedStringResource("chart.diskIO.times"))") + Text(" (%)"))
                    .font(.headline)
                if systemName == nil {
                    Text("chart.diskIO.times.subtitle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let systemName = systemName {
                    Text(systemName).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            VStack(spacing: 4) {
                Chart(dataPoints) { point in
                    let stats = point.extraFilesystems.first(where: { $0.name == diskName })?.diskIOStats
                    let readTime = stats?.readTimePct ?? 0
                    let writeTime = stats?.writeTimePct ?? 0
                    Plot {
                        LineMark(x: .value("Date", point.date), y: .value("Read", readTime), series: .value("S", "Read"))
                            .foregroundStyle(.blue)
                        AreaMark(x: .value("Date", point.date), yStart: .value("", 0), yEnd: .value("Read", readTime), series: .value("S", "Read"))
                            .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                    }
                    Plot {
                        LineMark(x: .value("Date", point.date), y: .value("Write", writeTime), series: .value("S", "Write"))
                            .foregroundStyle(.orange)
                        AreaMark(x: .value("Date", point.date), yStart: .value("", 0), yEnd: .value("Write", writeTime), series: .value("S", "Write"))
                            .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                    }
                }
                .chartYScale(domain: 0...min(niceYDomain(maxVal: Swift.max(maxTime, 1)).max, 100))
                .chartXAxis { AxisMarks(values: insetTickDates(for: chartXDomain)) { value in
                    if chartShowXGridLines {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    }
                    AxisValueLabel(anchor: value.edgeAnchor, collisionResolution: .disabled) {
                        if let date = value.as(Date.self) {
                            compactXAxisLabel(for: date, xAxisFormat: xAxisFormat, xDomain: chartXDomain, index: value.index)
                        }
                    }
                } }
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

                HStack(spacing: 12) {
                    HStack(spacing: 4) { Circle().fill(.blue).frame(width: 8, height: 8); Text("chart.diskIO.readTime").font(.caption2).foregroundStyle(.secondary) }
                    HStack(spacing: 4) { Circle().fill(.orange).frame(width: 8, height: 8); Text("chart.diskIO.writeTime").font(.caption2).foregroundStyle(.secondary) }
                }
            }
            .frame(height: 200)
        }
    }
}

struct ExtraDiskAwaitChartView: View {
    let diskName: String
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.chartShowXGridLines) private var chartShowXGridLines

    private var maxAwait: Double {
        dataPoints.compactMap {
            $0.extraFilesystems.first(where: { $0.name == diskName })?.diskIOStats
        }.flatMap { [$0.rAwait, $0.wAwait] }.max() ?? 0
    }

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("\(diskName) \(LocalizedStringResource("chart.diskIO.await"))") + Text(" (ms)"))
                    .font(.headline)
                if systemName == nil {
                    Text("chart.diskIO.await.subtitle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let systemName = systemName {
                    Text(systemName).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            VStack(spacing: 4) {
                Chart(dataPoints) { point in
                    let stats = point.extraFilesystems.first(where: { $0.name == diskName })?.diskIOStats
                    let rAwait = stats?.rAwait ?? 0
                    let wAwait = stats?.wAwait ?? 0
                    Plot {
                        LineMark(x: .value("Date", point.date), y: .value("rAwait", rAwait), series: .value("S", "Read"))
                            .foregroundStyle(.blue)
                        AreaMark(x: .value("Date", point.date), yStart: .value("", 0), yEnd: .value("rAwait", rAwait), series: .value("S", "Read"))
                            .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                    }
                    Plot {
                        LineMark(x: .value("Date", point.date), y: .value("wAwait", wAwait), series: .value("S", "Write"))
                            .foregroundStyle(.orange)
                        AreaMark(x: .value("Date", point.date), yStart: .value("", 0), yEnd: .value("wAwait", wAwait), series: .value("S", "Write"))
                            .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                    }
                }
                .chartXAxis { AxisMarks(values: insetTickDates(for: chartXDomain)) { value in
                    if chartShowXGridLines {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    }
                    AxisValueLabel(anchor: value.edgeAnchor, collisionResolution: .disabled) {
                        if let date = value.as(Date.self) {
                            compactXAxisLabel(for: date, xAxisFormat: xAxisFormat, xDomain: chartXDomain, index: value.index)
                        }
                    }
                } }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.1f", v)).font(.caption2).padding(.trailing, 6)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...niceYDomain(maxVal: Swift.max(maxAwait, 1)).max)
                .chartLegend(.hidden)
                .chartXScaleIfNeeded(chartXDomain)
                .padding(.top, 5)
                .frame(height: 185)
                .drawingGroup()

                HStack(spacing: 12) {
                    HStack(spacing: 4) { Circle().fill(.blue).frame(width: 8, height: 8); Text("chart.diskIO.rAwait").font(.caption2).foregroundStyle(.secondary) }
                    HStack(spacing: 4) { Circle().fill(.orange).frame(width: 8, height: 8); Text("chart.diskIO.wAwait").font(.caption2).foregroundStyle(.secondary) }
                }
            }
            .frame(height: 200)
        }
    }
}

struct ExtraDiskIOQueueDepthChartView: View {
    let diskName: String
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.chartShowXGridLines) private var chartShowXGridLines

    private var maxDepth: Double {
        dataPoints.compactMap {
            $0.extraFilesystems.first(where: { $0.name == diskName })?.diskIOStats?.weightedIO
        }.max() ?? 0
    }

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(diskName) \(LocalizedStringResource("chart.diskIO.queueDepth"))")
                    .font(.headline)
                if systemName == nil {
                    Text("chart.diskIO.queueDepth.subtitle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let systemName = systemName {
                    Text(systemName).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            Chart(dataPoints) { point in
                let depth = point.extraFilesystems.first(where: { $0.name == diskName })?.diskIOStats?.weightedIO ?? 0
                LineMark(x: .value("Date", point.date), y: .value("Depth", depth))
                    .foregroundStyle(.teal)
                AreaMark(x: .value("Date", point.date), yStart: .value("", 0), yEnd: .value("Depth", depth))
                    .foregroundStyle(LinearGradient(colors: [.teal.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
            }
            .chartXAxis { AxisMarks(values: insetTickDates(for: chartXDomain)) { value in
                    if chartShowXGridLines {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    }
                    AxisValueLabel(anchor: value.edgeAnchor, collisionResolution: .disabled) {
                        if let date = value.as(Date.self) {
                            compactXAxisLabel(for: date, xAxisFormat: xAxisFormat, xDomain: chartXDomain, index: value.index)
                        }
                    }
                } }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            let s = v.truncatingRemainder(dividingBy: 1) == 0
                                ? String(format: "%.0f", v)
                                : String(format: "%.2f", v)
                            Text(s).font(.caption2).padding(.trailing, 6)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...niceYDomain(maxVal: Swift.max(maxDepth, 1)).max)
            .chartLegend(.hidden)
            .chartXScaleIfNeeded(chartXDomain)
            .padding(.top, 5)
            .frame(height: 200)
            .drawingGroup()
        }
    }
}
