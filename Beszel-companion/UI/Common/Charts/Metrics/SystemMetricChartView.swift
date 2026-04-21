import SwiftUI
import Charts
import WidgetKit

struct SystemMetricChartView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.chartShowXGridLines) private var chartShowXGridLines
    
    let title: LocalizedStringResource
    let xAxisFormat: Date.FormatStyle
    let dataPoints: [SystemDataPoint]
    let valueKeyPath: KeyPath<SystemDataPoint, Double>
    let color: Color
    
    var subtitle: LocalizedStringResource? = nil
    var unit: String = ""
    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}
    var isForWidget: Bool = false

    var body: some View {
        if !isForWidget {
            GroupBox(label: HStack {
                VStack(alignment: .leading, spacing: 2) {
                    (unit.isEmpty ? Text(title) : Text(title) + Text(" (\(unit))"))
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
                    }
                }
                Spacer()
                PinButtonView(isPinned: isPinned, action: onPinToggle)
            }) {
                chartContent
                    .frame(height: 200)
            }
        } else {
            GroupBox(label: HStack {
                Text(title)
                    .bold()
                Spacer()
            }) {
                switch widgetFamily {
                case .systemSmall:
                    chartContent
                        .chartLegend(.hidden)
                        .chartYAxis(.hidden)
                        .chartXAxis(.hidden)
                case .systemMedium, .systemLarge:
                    chartContent
                        .chartLegend(position: .bottom, alignment: .center)
                        .chartXAxis {
                            AxisMarks(values: insetTickDates(for: chartXDomain)) { _ in
                    if chartShowXGridLines {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    }
                    AxisValueLabel(format: xAxisFormat, anchor: .top, collisionResolution: .disabled)
                        .font(.caption2)
                }
                        }
                default:
                    chartContent
                }
            }
            .groupBoxStyle(PlainGroupBoxStyle())
        }
    }

    private var latestValue: Double? {
        dataPoints.last?[keyPath: valueKeyPath]
    }

    private var maxDataValue: Double {
        dataPoints.map { $0[keyPath: valueKeyPath] }.max() ?? 0
    }

    private var chartContent: some View {
        Chart(dataPoints) { point in
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
            AxisMarks(values: insetTickDates(for: chartXDomain)) { _ in
                    if chartShowXGridLines {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    }
                    AxisValueLabel(format: xAxisFormat, anchor: .top, collisionResolution: .disabled)
                        .font(.caption2)
                }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(adaptiveAxisLabel(v, domainMax: maxDataValue)).font(.caption2).padding(.trailing, 6)
                    }
                }
            }
        }
        .chartXScaleIfNeeded(chartXDomain)
        .padding(.top, 5)
        .drawingGroup()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(latestValue.map { String(format: "%.1f%%", $0) } ?? "")
    }
    
    struct PlainGroupBoxStyle: GroupBoxStyle {
        func makeBody(configuration: Configuration) -> some View {
            VStack(alignment: .leading) {
                configuration.label
                configuration.content
            }
        }
    }
}
