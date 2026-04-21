import SwiftUI
import Charts

struct ExtraDiskIOSummaryChartView: View {
    let diskName: String
    let dataPoints: [SystemDataPoint]
    let systemID: String?
    var systemName: String? = nil

    @Environment(SettingsManager.self) var settingsManager
    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.chartShowXGridLines) private var chartShowXGridLines

    private var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }

    private var filteredPoints: [SystemDataPoint] {
        dataPoints.filter { $0.extraFilesystems.contains { $0.name == diskName } }
    }

    private var maxIO: Double {
        filteredPoints.compactMap { point in
            point.extraFilesystems.first(where: { $0.name == diskName })
        }.flatMap { [($0.diskRead ?? 0), ($0.diskWrite ?? 0)] }.max() ?? 0
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

    private var unitLabel: String {
        if maxIO >= 1_073_741_824 { return "GB/s" }
        if maxIO >= 1_048_576 { return "MB/s" }
        if maxIO >= 1024 { return "KB/s" }
        return "B/s"
    }

    var body: some View {
        NavigationLink(destination: DetailedExtraDiskIOView(
            diskName: diskName,
            dataPoints: dataPoints,
            xAxisFormat: xAxisFormat,
            systemID: systemID,
            xDomain: chartXDomain
        )) {
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
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }) {
                VStack(spacing: 4) {
                    Chart(filteredPoints) { point in
                        if let fs = point.extraFilesystems.first(where: { $0.name == diskName }),
                           let read = fs.diskRead, let write = fs.diskWrite {
                            Plot {
                                LineMark(x: .value("Date", point.date), y: .value("Read", read), series: .value("S", "Read"))
                                    .foregroundStyle(.blue)
                                AreaMark(x: .value("Date", point.date), yStart: .value("", 0), yEnd: .value("Read", read), series: .value("S", "Read"))
                                    .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                            }
                            Plot {
                                LineMark(x: .value("Date", point.date), y: .value("Write", write), series: .value("S", "Write"))
                                    .foregroundStyle(.orange)
                                AreaMark(x: .value("Date", point.date), yStart: .value("", 0), yEnd: .value("Write", write), series: .value("S", "Write"))
                                    .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                            }
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
                                if let b = value.as(Double.self) {
                                    let s = formatBytes(b)
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
                        HStack(spacing: 4) { Circle().fill(.blue).frame(width: 8, height: 8); Text("chart.diskIO.read").font(.caption2).foregroundStyle(.secondary) }
                        HStack(spacing: 4) { Circle().fill(.orange).frame(width: 8, height: 8); Text("chart.diskIO.write").font(.caption2).foregroundStyle(.secondary) }
                    }
                }
                .frame(height: 200)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
