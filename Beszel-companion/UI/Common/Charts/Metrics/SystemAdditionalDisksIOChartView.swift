import SwiftUI
import Charts

struct ExtraDiskUsageChartView: View {
    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.chartShowXGridLines) private var chartShowXGridLines
    let diskName: String
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var systemName: String? = nil

    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    private var totalDisk: Double {
        dataPoints.compactMap { $0.extraFilesystems.first(where: { $0.name == diskName })?.total }.max() ?? 0
    }

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("chart.extraDisk.usage.title \(diskName)") + Text(" (\(diskSizeUnit))"))
                    .font(.headline)
                if systemName == nil {
                    Text("chart.extraDiskUsage.subtitle \(diskName)")
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
            Chart {
                ForEach(dataPoints) { point in
                    if let fs = point.extraFilesystems.first(where: { $0.name == diskName }) {
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Used", fs.used),
                        )
                        .foregroundStyle(.purple)

                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Type", 0),
                            yEnd: .value("Used", fs.used),
                        )
                        .foregroundStyle(LinearGradient(colors: [.purple.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                    }
                }
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
                AxisMarks(position: .leading, values: capacityTicks(total: totalDisk)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let gb = value.as(Double.self) {
                            let s = gb == 0 ? "0" : adaptiveAxisLabel(gb * unitScale, domainMax: totalDisk * unitScale)
                            Text(s).font(.caption2).padding(.trailing, 6)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...Swift.max(totalDisk, 0.001))
            .chartLegend(.hidden)
            .chartXScaleIfNeeded(chartXDomain)
            .padding(.top, 5)
            .frame(height: 185)
            .drawingGroup()

            HStack(spacing: 4) {
                Circle().fill(.purple).frame(width: 8, height: 8)
                Text("chart.disk.used").font(.caption2).foregroundStyle(.secondary)
            }
            }
            .frame(height: 200)
        }
    }

    private var diskSizeUnit: String {
        if totalDisk >= 1024 { return "TB" }
        if totalDisk >= 1    { return "GB" }
        return "MB"
    }

    /// Converts GB values to the unit shown in the title.
    private var unitScale: Double {
        if totalDisk >= 1024 { return 1.0 / 1024 }
        if totalDisk >= 1    { return 1 }
        return 1024
    }
}

struct ExtraDiskIOChartView: View {
    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.chartShowXGridLines) private var chartShowXGridLines
    let diskName: String
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var systemName: String? = nil

    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    private var maxIO: Double {
        dataPoints.compactMap { point in
            point.extraFilesystems.first(where: { $0.name == diskName })
        }.map { Swift.max($0.diskRead ?? 0, $0.diskWrite ?? 0) }.max() ?? 0
    }

    private var unitLabel: String {
        if maxIO >= 1_073_741_824 { return "GB/s" }
        if maxIO >= 1_048_576 { return "MB/s" }
        if maxIO >= 1024 { return "KB/s" }
        return "B/s"
    }

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("chart.extraDisk.io.title \(diskName)") + Text(" (\(unitLabel))"))
                    .font(.headline)
                if systemName == nil {
                    Text("chart.extraDiskIO.subtitle \(diskName)")
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
                if let fs = point.extraFilesystems.first(where: { $0.name == diskName }),
                   let read = fs.diskRead, let write = fs.diskWrite {
                    Plot {
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Read", read),
                            series: .value("Period", "Read")
                        )
                        .foregroundStyle(.blue)

                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Period", 0),
                            yEnd: .value("Read", read),
                            series: .value("Period", "Read")
                        )
                        .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                    }

                    Plot {
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Write", write),
                            series: .value("Period", "Write")
                        )
                        .foregroundStyle(.orange)

                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Period", 0),
                            yEnd: .value("Write", write),
                            series: .value("Period", "Write")
                        )
                        .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                    }
                }
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
                        if let bytes = value.as(Double.self) {
                            let s = formatBytes(bytes)
                            Text(s).font(.caption2).padding(.trailing, 6)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...niceYDomain(maxVal: Swift.max(maxIO, 1)).max)
            .chartLegend(.hidden)
            .chartXScaleIfNeeded(chartXDomain)
            .padding(.top, 5)
            .frame(height: 185)
            .drawingGroup()

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle().fill(.blue).frame(width: 8, height: 8)
                    Text("chart.diskIO.read").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(.orange).frame(width: 8, height: 8)
                    Text("chart.diskIO.write").font(.caption2).foregroundStyle(.secondary)
                }
            }
            }
            .frame(height: 200)
        }
    }

    private func formatBytes(_ bytes: Double) -> String {
        func fmt(_ v: Double) -> String {
            v.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", v) : String(format: "%.1f", v)
        }
        if bytes == 0 { return "0" }
        if bytes >= 1_073_741_824 { return fmt(bytes / 1_073_741_824) }
        if bytes >= 1_048_576     { return fmt(bytes / 1_048_576) }
        if bytes >= 1024          { return fmt(bytes / 1024) }
        return String(format: "%.0f", bytes)
    }
}
