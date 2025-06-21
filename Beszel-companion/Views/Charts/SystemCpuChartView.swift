import SwiftUI
import Charts

struct SystemCpuChartView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    let dataPoints: [SystemDataPoint]

    var body: some View {
        GroupBox(label:
            HStack {
                Text("Utilisation CPU (%)")
                Spacer()
                PinButtonView(item: .systemCPU)
            }
        ) {
            Chart(dataPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("CPU", point.cpu)
                )
                .foregroundStyle(.blue)
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("CPU", point.cpu)
                )
                .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: settingsManager.selectedTimeRange.xAxisFormat, centered: true)
                }
            }
            .chartYScale(domain: 0...100)
            .frame(height: 200)
        }
    }
}
