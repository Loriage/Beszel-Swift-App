import SwiftUI
import Charts

struct ContainerMemoryChartView: View {
    let xAxisFormat: Date.FormatStyle
    let container: ProcessedContainerData
    
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    var body: some View {
        GroupBox(label:
            HStack {
                Text("\(LocalizedStringResource("chart.container.memoryUsage.bytes")) \(container.name)")
                Spacer()
                PinButtonView(isPinned: isPinned, action: onPinToggle)
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
                    AxisValueLabel(format: xAxisFormat, centered: true)
                }
            }
            .frame(height: 200)
        }
    }
}
