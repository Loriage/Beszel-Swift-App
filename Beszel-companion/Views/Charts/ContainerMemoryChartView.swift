import SwiftUI
import Charts

struct ContainerMemoryChartView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    let container: ProcessedContainerData

    var body: some View {
        GroupBox(label:
            HStack {
                Text("Utilisation Mémoire (Mo)")
                Spacer()
                PinButtonView(item: .containerMemory(name: container.name))
            }
        ) {
            Chart(container.statPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Mémoire", point.memory)
                )
                .foregroundStyle(.green)
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
