import SwiftUI
import Charts

struct SystemDiskUsageChartView: View {
    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.chartShowXGridLines) private var chartShowXGridLines
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var systemName: String? = nil
    var diskName: String? = nil

    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    private var totalDisk: Double {
        dataPoints.compactMap { $0.diskUsage?.total }.max() ?? 0
    }

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("chart.diskUsage") + Text(" (\(totalDisk >= 1024 ? "TB" : "GB"))"))
                    .font(.headline)
                if let diskName, !diskName.isEmpty {
                    Text(verbatim: diskName).font(.subheadline)
                }
                if systemName == nil {
                    Text("chart.diskUsage.subtitle")
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
                        if let disk = point.diskUsage {
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Used", disk.used),
                            )
                            .foregroundStyle(.purple)

                            AreaMark(
                                x: .value("Date", point.date),
                                yStart: .value("Type", 0),
                                yEnd: .value("Used", disk.used),
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
                                let divisor = totalDisk >= 1024 ? 1024.0 : 1
                                let s = gb == 0 ? "0" : adaptiveAxisLabel(gb / divisor, domainMax: totalDisk / divisor)
                                Text(s).font(.caption2).padding(.trailing, 6)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...Swift.max(totalDisk, 1))
                .chartLegend(.hidden)
                .chartXScaleIfNeeded(chartXDomain)
                .padding(.top, 5)
                .frame(height: 185)
                .drawingGroup()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("chart.diskUsage"))
                .accessibilityValue(accessibilityDescription)

                HStack(spacing: 4) {
                    Circle().fill(.purple).frame(width: 8, height: 8)
                    Text("chart.disk.used").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(height: 200)
        }
    }

    private var accessibilityDescription: String {
        guard let latest = dataPoints.last?.diskUsage else { return "" }
        return String(format: "Used: %.1f GB of %.1f GB", latest.used, latest.total)
    }
}
