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
                Text("chart.loadAverage")
                    .font(.headline)
                if systemName == nil {
                    Text("chart.loadAverage.subtitle")
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
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartLegend(.hidden)
            .padding(.top, 5)
            .frame(height: 185)
            .drawingGroup()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("chart.loadAverage"))
            .accessibilityValue(accessibilityDescription)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle().fill(.purple).frame(width: 8, height: 8)
                    Text("chart.load.1min").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(.blue).frame(width: 8, height: 8)
                    Text("chart.load.5min").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(.orange).frame(width: 8, height: 8)
                    Text("chart.load.15min").font(.caption2).foregroundStyle(.secondary)
                }
            }
            }
            .frame(height: 200)
        }
    }

    private var accessibilityDescription: String {
        guard let latest = dataPoints.last?.loadAverage else { return "" }
        return String(format: "1 min: %.2f, 5 min: %.2f, 15 min: %.2f", latest.l1, latest.l5, latest.l15)
    }
}
