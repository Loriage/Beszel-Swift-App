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

    private var maxValue: Double {
        let max = container.statPoints.map { $0[keyPath: valueKeyPath] }.max() ?? 0
        return max == 0 ? 1.0 : max
    }
    
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
            .chartYScale(domain: 0...maxValue)
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
            .frame(height: 200)
        }
    }
}
