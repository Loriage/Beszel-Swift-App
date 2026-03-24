import SwiftUI
import Charts

struct ExtraDiskUsageChartView: View {
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
                Text("\(LocalizedStringResource("chart.extraDisk.usage")) \(diskName)")
                    .font(.headline)
                if let systemName = systemName {
                    Text(systemName)
                        .font(.caption)
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
                            series: .value("Type", "Used")
                        )
                        .foregroundStyle(.purple)

                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Type", 0),
                            yEnd: .value("Used", fs.used),
                            series: .value("Type", "Used")
                        )
                        .foregroundStyle(LinearGradient(colors: [.purple.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                    }
                }
                RuleMark(y: .value("Total", totalDisk))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: xAxisFormat, centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let gb = value.as(Double.self) {
                            Text(formatDiskSize(gb))
                                .font(.caption)
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .padding(.top, 5)
            .frame(height: 185)
            .drawingGroup()

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle().fill(.purple).frame(width: 8, height: 8)
                    Text("chart.disk.used").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(.gray.opacity(0.5))
                        .frame(width: 12, height: 1.5)
                    Text("chart.disk.total").font(.caption2).foregroundStyle(.secondary)
                }
            }
            }
            .frame(height: 200)
        }
    }

    private func formatDiskSize(_ gb: Double) -> String {
        if gb >= 1024 {
            return String(format: "%.1f TB", gb / 1024)
        } else if gb >= 1 {
            return String(format: "%.0f GB", gb)
        } else {
            return String(format: "%.0f MB", gb * 1024)
        }
    }
}

struct ExtraDiskIOChartView: View {
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
                Text("\(LocalizedStringResource("chart.extraDisk.io")) \(diskName) (\(unitLabel))")
                    .font(.headline)
                if let systemName = systemName {
                    Text(systemName)
                        .font(.caption)
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
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: xAxisFormat, centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let bytes = value.as(Double.self) {
                            Text(formatBytes(bytes))
                                .font(.caption)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...Swift.max(maxIO, 1))
            .chartLegend(.hidden)
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
        if bytes >= 1_073_741_824 {
            return String(format: "%.1f GB/s", bytes / 1_073_741_824)
        } else if bytes >= 1_048_576 {
            return String(format: "%.1f MB/s", bytes / 1_048_576)
        } else if bytes >= 1024 {
            return String(format: "%.1f KB/s", bytes / 1024)
        } else {
            return String(format: "%.0f B/s", bytes)
        }
    }
}
