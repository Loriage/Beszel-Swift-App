import SwiftUI
import Charts

struct SystemDiskIOChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}
    
    var body: some View {
        GroupBox(label: HStack {
            Text("Disk I/O")
                .font(.headline)
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            Chart(dataPoints) { point in
                if let io = point.diskIO {
                    // Read (Orange)
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Read", io.read)
                    )
                    .foregroundStyle(.orange)
                    
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Read", io.read)
                    )
                    .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                    
                    // Write (Violet)
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Write", io.write)
                    )
                    .foregroundStyle(.purple)
                    
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Write", io.write)
                    )
                    .foregroundStyle(LinearGradient(colors: [.purple.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
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
                            Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary) + "/s")
                        }
                    }
                }
            }
            .chartForegroundStyleScale([
                "Read": .orange,
                "Write": .purple
            ])
            .chartLegend(position: .bottom, alignment: .leading)
            .padding(.top, 5)
            .frame(height: 200)
            .drawingGroup()
        }
    }
}
