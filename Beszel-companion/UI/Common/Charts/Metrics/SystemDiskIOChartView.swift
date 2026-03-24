import SwiftUI
import Charts

struct SystemDiskIOChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var systemName: String? = nil
    
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}
    
    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
            Text("chart.diskIO")
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
            .accessibilityLabel(Text("chart.diskIO"))
            .accessibilityValue(accessibilityDescription)

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

    private var accessibilityDescription: String {
        guard let latest = dataPoints.last?.diskIO else { return "" }
        let read = latest.read / 1024_000.0
        let write = latest.write / 1024_000.0
        return String(format: "Read: %.1f MB/s, Write: %.1f MB/s", read, write)
    }
}
