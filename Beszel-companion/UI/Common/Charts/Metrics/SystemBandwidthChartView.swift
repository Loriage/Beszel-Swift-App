import SwiftUI
import Charts

struct SystemBandwidthChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var systemName: String? = nil

    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
            Text("chart.bandwidth")
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
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let bytes = value.as(Double.self) {
                            let labelText = String(format: "%.1f", bytes / 1024_000.0)
                            Text(labelText)
                                .font(.caption)
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .padding(.top, 5)
            .frame(height: 185)
            .drawingGroup()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("chart.bandwidth"))
            .accessibilityValue(accessibilityDescription)

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

    private var accessibilityDescription: String {
        guard let latest = dataPoints.last?.bandwidth else { return "" }
        let download = latest.download / 1024_000.0
        let upload = latest.upload / 1024_000.0
        return String(format: "Download: %.1f MB/s, Upload: %.1f MB/s", download, upload)
    }
}
