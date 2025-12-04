import SwiftUI
import Charts
import WidgetKit

struct SystemMemoryChartView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    
    let xAxisFormat: Date.FormatStyle
    let dataPoints: [SystemDataPoint]
    var systemName: String? = nil
    
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}
    
    var isForWidget: Bool = false
    
    var body: some View {
        if !isForWidget {
            GroupBox(label: HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("chart.memoryUsage")
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
            GroupBox(label:
                HStack {
                    Text("chart.memoryUsage")
                    .bold()
                    Spacer()
                }
            ) {
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

    struct PlainGroupBoxStyle: GroupBoxStyle {
        func makeBody(configuration: Configuration) -> some View {
            VStack(alignment: .leading) {
                configuration.label
                configuration.content
            }
        }
    }

    private var chartContent: some View {
        Chart(dataPoints) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Mémoire", point.memoryPercent)
            )
            .foregroundStyle(.green)
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Mémoire", point.memoryPercent)
            )
            .foregroundStyle(LinearGradient(colors: [.green.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisValueLabel(format: xAxisFormat, centered: true)
            }
        }
        .padding(.top, 5)
        .drawingGroup()
    }
}
