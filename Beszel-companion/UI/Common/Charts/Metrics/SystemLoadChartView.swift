import SwiftUI
import Charts

struct SystemLoadChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle

    var systemName: String? = nil
    
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}
    
    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
            Text("Load Average")
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
                String(localized: "1 min"): .purple,
                String(localized: "5 min"): .blue,
                String(localized: "15 min"): .orange
            ])
            .chartLegend(position: .bottom, alignment: .center)
            .padding(.top, 5)
            .frame(height: 200)
            .drawingGroup()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Load Average"))
            .accessibilityValue(accessibilityDescription)
        }
    }

    private var accessibilityDescription: String {
        guard let latest = dataPoints.last?.loadAverage else { return "" }
        return String(format: "1 min: %.2f, 5 min: %.2f, 15 min: %.2f", latest.l1, latest.l5, latest.l15)
    }
}
