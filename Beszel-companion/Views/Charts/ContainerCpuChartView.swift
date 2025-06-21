import SwiftUI
import Charts

struct ContainerCpuChartView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    let container: ProcessedContainerData

    var body: some View {
        GroupBox(label:
            HStack {
                Text("Utilisation CPU (%)")
                Spacer()
                PinButtonView(item: .containerCPU(name: container.name))
            }
        ) {
            Chart(container.statPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("CPU", point.cpu)
                )
                .foregroundStyle(.blue)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: settingsManager.selectedTimeRange.xAxisFormat, centered: true)
                }
            }
            .frame(height: 200)
        }
    }
}
