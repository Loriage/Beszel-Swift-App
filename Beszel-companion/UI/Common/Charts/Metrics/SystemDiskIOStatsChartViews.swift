import SwiftUI
import Charts

struct SystemDiskIOUtilizationChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    @Environment(\.chartXDomain) private var chartXDomain

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("chart.disk.prefix") + Text(" ") + Text("chart.diskIO.utilization") + Text(" (%)"))
                    .font(.headline)
                if systemName == nil {
                    Text("chart.diskIO.utilization.subtitle")
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
            Chart(dataPoints) { point in
                if let stats = point.diskIOStats {
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Util", stats.utilPct)
                    )
                    .foregroundStyle(.purple)
                    AreaMark(
                        x: .value("Date", point.date),
                        yStart: .value("", 0),
                        yEnd: .value("Util", stats.utilPct)
                    )
                    .foregroundStyle(LinearGradient(colors: [.purple.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: xAxisFormat, centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(String(format: "%.0f", v)).font(.caption2)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .chartLegend(.hidden)
            .chartXScaleIfNeeded(chartXDomain)
            .padding(.top, 5)
            .frame(height: 200)
            .drawingGroup()
        }
    }
}

struct SystemDiskIOTimesChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    @Environment(\.chartXDomain) private var chartXDomain

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("chart.disk.prefix") + Text(" ") + Text("chart.diskIO.times") + Text(" (%)"))
                    .font(.headline)
                if systemName == nil {
                    Text("chart.diskIO.times.subtitle")
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
                Chart(dataPoints) { point in
                    if let stats = point.diskIOStats {
                        Plot {
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Read", stats.readTimePct),
                                series: .value("S", "Read")
                            )
                            .foregroundStyle(.blue)
                            AreaMark(
                                x: .value("Date", point.date),
                                yStart: .value("", 0),
                                yEnd: .value("Read", stats.readTimePct),
                                series: .value("S", "Read")
                            )
                            .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                        }
                        Plot {
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Write", stats.writeTimePct),
                                series: .value("S", "Write")
                            )
                            .foregroundStyle(.orange)
                            AreaMark(
                                x: .value("Date", point.date),
                                yStart: .value("", 0),
                                yEnd: .value("Write", stats.writeTimePct),
                                series: .value("S", "Write")
                            )
                            .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel(format: xAxisFormat, centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0f", v)).font(.caption2)
                            }
                        }
                    }
                }
                    .chartYScale(domain: 0...100)
                .chartLegend(.hidden)
                .chartXScaleIfNeeded(chartXDomain)
                .padding(.top, 5)
                .frame(height: 185)
                .drawingGroup()

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(.blue).frame(width: 8, height: 8)
                        Text("chart.diskIO.readTime").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(.orange).frame(width: 8, height: 8)
                        Text("chart.diskIO.writeTime").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 200)
        }
    }
}

struct SystemDiskAwaitChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    @Environment(\.chartXDomain) private var chartXDomain

    private var maxAwait: Double {
        dataPoints.compactMap { $0.diskIOStats }.flatMap { [$0.rAwait, $0.wAwait] }.max() ?? 0
    }

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("chart.disk.prefix") + Text(" ") + Text("chart.diskIO.await") + Text(" (ms)"))
                    .font(.headline)
                if systemName == nil {
                    Text("chart.diskIO.await.subtitle")
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
                Chart(dataPoints) { point in
                    if let stats = point.diskIOStats {
                        Plot {
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("rAwait", stats.rAwait),
                                series: .value("S", "Read")
                            )
                            .foregroundStyle(.blue)
                            AreaMark(
                                x: .value("Date", point.date),
                                yStart: .value("", 0),
                                yEnd: .value("rAwait", stats.rAwait),
                                series: .value("S", "Read")
                            )
                            .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                        }
                        Plot {
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("wAwait", stats.wAwait),
                                series: .value("S", "Write")
                            )
                            .foregroundStyle(.orange)
                            AreaMark(
                                x: .value("Date", point.date),
                                yStart: .value("", 0),
                                yEnd: .value("wAwait", stats.wAwait),
                                series: .value("S", "Write")
                            )
                            .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel(format: xAxisFormat, centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.1f", v)).font(.caption2)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...Swift.max(maxAwait * 1.15, 1.0))
                .chartLegend(.hidden)
                .chartXScaleIfNeeded(chartXDomain)
                .padding(.top, 5)
                .frame(height: 185)
                .drawingGroup()

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(.blue).frame(width: 8, height: 8)
                        Text("chart.diskIO.rAwait").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(.orange).frame(width: 8, height: 8)
                        Text("chart.diskIO.wAwait").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 200)
        }
    }
}

struct SystemDiskIOQueueDepthChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    @Environment(\.chartXDomain) private var chartXDomain

    private var maxDepth: Double {
        dataPoints.compactMap { $0.diskIOStats?.weightedIO }.max() ?? 0
    }

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("chart.disk.prefix") + Text(" ") + Text("chart.diskIO.queueDepth"))
                    .font(.headline)
                if systemName == nil {
                    Text("chart.diskIO.queueDepth.subtitle")
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
            Chart(dataPoints) { point in
                let depth = point.diskIOStats?.weightedIO ?? 0
                LineMark(x: .value("Date", point.date), y: .value("Depth", depth))
                    .foregroundStyle(.teal)
                AreaMark(x: .value("Date", point.date), yStart: .value("", 0), yEnd: .value("Depth", depth))
                    .foregroundStyle(LinearGradient(colors: [.teal.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: xAxisFormat, centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            let s = v.truncatingRemainder(dividingBy: 1) == 0
                                ? String(format: "%.0f", v)
                                : String(format: "%.2f", v)
                            Text(s).font(.caption2)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...Swift.max(maxDepth * 1.15, 1))
            .chartLegend(.hidden)
            .chartXScaleIfNeeded(chartXDomain)
            .padding(.top, 5)
            .frame(height: 200)
            .drawingGroup()
        }
    }
}
