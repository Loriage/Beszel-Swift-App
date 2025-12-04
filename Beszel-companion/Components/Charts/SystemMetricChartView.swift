import SwiftUI
import Charts
import WidgetKit

struct SystemMetricChartView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    
    let title: LocalizedStringResource
    let xAxisFormat: Date.FormatStyle
    let dataPoints: [SystemDataPoint]
    let valueKeyPath: KeyPath<SystemDataPoint, Double>
    let color: Color
    
    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}
    var isForWidget: Bool = false

    var body: some View {
        if !isForWidget {
            GroupBox(label: HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
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
                            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                AxisValueLabel(format: xAxisFormat, centered: true)
                            }
                        }
                default:
                    chartContent
                }
            }
            .groupBoxStyle(PlainGroupBoxStyle())
        }
    }

    private var chartContent: some View {
        Chart(dataPoints) { point in
            let value = point[keyPath: valueKeyPath]
            
            LineMark(
                x: .value("Date", point.date),
                y: .value("Valeur", value)
            )
            .foregroundStyle(color)
            
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Valeur", value)
            )
            .foregroundStyle(LinearGradient(colors: [color.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisValueLabel(format: xAxisFormat, centered: true)
            }
        }
        .padding(.top, 5)
        .drawingGroup()
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
