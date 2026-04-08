import SwiftUI
import Charts

struct BandwidthSummaryChartView: View {
    let dataPoints: [SystemDataPoint]
    let systemID: String?
    var systemName: String? = nil

    @Environment(SettingsManager.self) var settingsManager
    @Environment(\.chartXDomain) private var chartXDomain

    private var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }

    var body: some View {
        NavigationLink(destination: DetailedBandwidthView(
            dataPoints: dataPoints,
            xAxisFormat: xAxisFormat,
            systemID: systemID,
            xDomain: chartXDomain
        )) {
            GroupBox(label: HStack {
                VStack(alignment: .leading, spacing: 2) {
                    (Text("chart.bandwidth") + Text(" (MB/s)"))
                        .font(.headline)
                    if systemName == nil {
                        Text("chart.bandwidth.subtitle")
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
                        if let bandwidth = point.bandwidth {
                            Plot {
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Download", bandwidth.download),
                                    series: .value("Period", "Download")
                                )
                                .foregroundStyle(.green)
                                AreaMark(
                                    x: .value("Date", point.date),
                                    yStart: .value("Period", 0),
                                    yEnd: .value("Download", bandwidth.download),
                                    series: .value("Period", "Download")
                                )
                                .foregroundStyle(LinearGradient(colors: [.green.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                            }
                            Plot {
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Upload", bandwidth.upload),
                                    series: .value("Period", "Upload")
                                )
                                .foregroundStyle(.red)
                                AreaMark(
                                    x: .value("Date", point.date),
                                    yStart: .value("Period", 0),
                                    yEnd: .value("Upload", bandwidth.upload),
                                    series: .value("Period", "Upload")
                                )
                                .foregroundStyle(LinearGradient(colors: [.red.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
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
                            Circle().fill(.green).frame(width: 8, height: 8)
                            Text("chart.bandwidth.download").font(.caption2).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            Circle().fill(.red).frame(width: 8, height: 8)
                            Text("chart.bandwidth.upload").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
