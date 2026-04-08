import SwiftUI
import Charts

struct ContainerMetricChartView: View {
    let titleKey: String
    let containerName: String
    let xAxisFormat: Date.FormatStyle
    let container: ProcessedContainerData
    let valueKeyPath: KeyPath<StatPoint, Double>
    let color: Color
    
    var subtitleKey: String? = nil
    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}
    var yAxisFormatter: (Double) -> String = { String(format: "%.0f", $0) }
    var yAxisUnit: String = ""

    @Environment(\.chartXDomain) private var chartXDomain

    private var maxValue: Double {
        let max = container.statPoints.map { $0[keyPath: valueKeyPath] }.max() ?? 0
        return max == 0 ? 1.0 : max
    }

    var body: some View {
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("\(LocalizedStringResource(stringLiteral: titleKey)) \(containerName)")
                    + (yAxisUnit.isEmpty ? Text("") : Text(" (\(yAxisUnit))")))
                    .font(.headline)
                if let subtitleKey = subtitleKey, systemName == nil {
                    Text(LocalizedStringResource(stringLiteral: subtitleKey))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let systemName = systemName {
                    Text(systemName)
                        .font(.caption2)
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
            .chartXScaleIfNeeded(chartXDomain)
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
                            Text(yAxisFormatter(v)).font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 200)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(LocalizedStringResource(stringLiteral: titleKey)) \(containerName)"))
            .accessibilityValue(accessibilityDescription)
        }
    }

    private var accessibilityDescription: String {
        guard let latest = container.statPoints.last else { return "" }
        let value = latest[keyPath: valueKeyPath]
        return String(format: "%.1f", value)
    }
}
