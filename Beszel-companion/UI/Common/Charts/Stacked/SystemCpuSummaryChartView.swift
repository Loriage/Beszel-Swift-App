import SwiftUI
import Charts

struct SystemCpuSummaryChartView: View {
    let dataPoints: [SystemDataPoint]
    let systemID: String?
    var systemName: String? = nil

    @Environment(SettingsManager.self) var settingsManager
    @Environment(\.chartXDomain) private var chartXDomain

    private var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }

    var body: some View {
        NavigationLink(destination: SystemCpuDetailView(
            dataPoints: dataPoints,
            xAxisFormat: xAxisFormat,
            systemID: systemID,
            xDomain: chartXDomain
        )) {
            GroupBox(label: HStack {
                VStack(alignment: .leading, spacing: 2) {
                    (Text("chart.cpuUsage") + Text(" (%)"))
                        .font(.headline)
                    if systemName == nil {
                        Text("chart.cpuUsage.subtitle")
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
                Chart(dataPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("CPU", point.cpu)
                    )
                    .foregroundStyle(.blue)
                    AreaMark(
                        x: .value("Date", point.date),
                        yStart: .value("", 0),
                        yEnd: .value("CPU", point.cpu)
                    )
                    .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
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
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0f", v)).font(.caption2)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartLegend(.hidden)
                .chartXScaleIfNeeded(chartXDomain)
                .padding(.top, 5)
                .frame(height: 200)
                .drawingGroup()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
