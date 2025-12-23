import SwiftUI
import Charts

struct SystemLoadChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}
    
    var body: some View {
        GroupBox(label: HStack {
            Text("Load Average")
                .font(.headline)
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            Chart(dataPoints) { point in
                if let load = point.loadAverage {
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Load", load.l1),
                        series: .value("Period", "1 min")
                    )
                    .foregroundStyle(.purple)
                    .interpolationMethod(.catmullRom)
                    
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Load", load.l5),
                        series: .value("Period", "5 min")
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Load", load.l15),
                        series: .value("Period", "15 min")
                    )
                    .foregroundStyle(.orange)
                    .interpolationMethod(.catmullRom)
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
                    AxisValueLabel()
                }
            }
            .chartForegroundStyleScale([
                "1 min": .purple,
                "5 min": .blue,
                "15 min": .orange
            ])
            .chartLegend(position: .bottom, alignment: .center)
            .padding(.top, 5)
            .frame(height: 200)
            .drawingGroup()
        }
    }
}
