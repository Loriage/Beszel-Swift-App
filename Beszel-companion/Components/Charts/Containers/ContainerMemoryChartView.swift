import SwiftUI
import Charts

struct ContainerMemoryChartView: View {
    let xAxisFormat: Date.FormatStyle
    let container: ProcessedContainerData
    var systemName: String? = nil
    
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    var body: some View {
        GroupBox(label:
                    HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(LocalizedStringResource("chart.container.memoryUsage.bytes")) \(container.name)")
                    .font(.headline)
                if let systemName = systemName {
                    Text(systemName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            Chart(container.statPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Mémoire", point.memory)
                )
                .foregroundStyle(.green)
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Mémoire", point.memory)
                )
                .foregroundStyle(LinearGradient(colors: [.green.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
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
