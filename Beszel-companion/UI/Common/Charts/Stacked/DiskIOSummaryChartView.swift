import SwiftUI
import Charts

struct DiskIOSummaryChartView: View {
    let dataPoints: [SystemDataPoint]
    let systemID: String?
    var systemName: String? = nil

    @Environment(SettingsManager.self) var settingsManager
    @Environment(\.chartXDomain) private var chartXDomain

    private var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }

    private var maxIO: Double {
        dataPoints.compactMap { $0.diskIO }.flatMap { [$0.read, $0.write] }.max() ?? 0
    }

    var body: some View {
        NavigationLink(destination: DetailedDiskIOView(
            dataPoints: dataPoints,
            xAxisFormat: xAxisFormat,
            systemID: systemID,
            xDomain: chartXDomain
        )) {
            GroupBox(label: HStack {
                VStack(alignment: .leading, spacing: 2) {
                    (Text("chart.diskIO") + Text(" (MB/s)"))
                        .font(.headline)
                    if systemName == nil {
                        Text("chart.diskIO.subtitle")
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
                    Chart(dataPoints) { point in
                        if let io = point.diskIO {
                            Plot {
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Read", io.read),
                                    series: .value("Period", "Read")
                                )
                                .foregroundStyle(.blue)
                                AreaMark(
                                    x: .value("Date", point.date),
                                    yStart: .value("Period", 0),
                                    yEnd: .value("Read", io.read),
                                    series: .value("Period", "Read")
                                )
                                .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                            }
                            Plot {
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Write", io.write),
                                    series: .value("Period", "Write")
                                )
                                .foregroundStyle(.orange)
                                AreaMark(
                                    x: .value("Date", point.date),
                                    yStart: .value("Period", 0),
                                    yEnd: .value("Write", io.write),
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
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let bytes = value.as(Double.self) {
                                    let v = bytes / 1_048_576.0
                                    let s = bytes == 0 ? "0"
                                        : v.truncatingRemainder(dividingBy: 1) == 0
                                            ? String(format: "%.0f", v)
                                            : String(format: "%.1f", v)
                                    Text(s).font(.caption2)
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
        .buttonStyle(PlainButtonStyle())
    }
}
