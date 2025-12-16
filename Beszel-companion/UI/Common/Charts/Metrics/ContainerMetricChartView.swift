import SwiftUI
import Charts

struct ContainerMetricChartView: View {
    let titleKey: String
    let containerName: String
    let xAxisFormat: Date.FormatStyle
    let container: ProcessedContainerData
    let valueKeyPath: KeyPath<StatPoint, Double>
    let color: Color
    
    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(LocalizedStringResource(stringLiteral: titleKey)) \(containerName)")
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
                let value = point[keyPath: valueKeyPath]
                
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", value)
                )
                .foregroundStyle(color)
                
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", value)
                )
                .foregroundStyle(LinearGradient(colors: [color.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
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
