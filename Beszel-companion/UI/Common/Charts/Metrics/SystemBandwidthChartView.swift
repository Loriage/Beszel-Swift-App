import SwiftUI
import Charts

struct SystemBandwidthChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    var body: some View {
        GroupBox(label: HStack {
            Text("Bandwidth (MB/s)")
                .font(.headline)
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            Chart(dataPoints) { point in
                if let bandwidth = point.bandwidth {
                    Plot {
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Download", bandwidth.download),
                            series: .value("", "Download")
                        )
                        .foregroundStyle(.green)
                        
                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("", 0),
                            yEnd: .value("Download", bandwidth.download),
                            series: .value("", "Download")
                        )
                        .foregroundStyle(LinearGradient(colors: [.green.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                    }
                    
                    Plot {
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Upload", bandwidth.upload),
                            series: .value("", "Upload")
                        )
                        .foregroundStyle(.red)
                        
                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("", 0),
                            yEnd: .value("Upload", bandwidth.upload),
                            series: .value("", "Upload")
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
            .chartLegend(position: .bottom, alignment: .leading)
            .padding(.top, 5)
            .frame(height: 200)
            .drawingGroup()
        }
    }
}
