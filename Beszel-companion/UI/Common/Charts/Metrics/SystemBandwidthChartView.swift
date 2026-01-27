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
            Text("Bandwidth (MB/s)")
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
            .chartForegroundStyleScale([
                String(localized: "Received"): .green,
                String(localized: "Sent"): .red,
            ])
            .chartLegend(position: .bottom, alignment: .center)
            .padding(.top, 5)
            .frame(height: 200)
            .drawingGroup()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Bandwidth (MB/s)"))
            .accessibilityValue(accessibilityDescription)
        }
    }

    private var accessibilityDescription: String {
        guard let latest = dataPoints.last?.bandwidth else { return "" }
        let download = latest.download / 1024_000.0
        let upload = latest.upload / 1024_000.0
        return String(format: "Download: %.1f MB/s, Upload: %.1f MB/s", download, upload)
    }
}
