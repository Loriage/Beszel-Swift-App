import SwiftUI
import Charts
import WidgetKit

struct SystemTemperatureChartView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    
    let xAxisFormat: Date.FormatStyle
    let dataPoints: [SystemDataPoint]

    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    var isForWidget: Bool = false

    var body: some View {
        if !isForWidget {
            GroupBox(label:
                HStack {
                    Text("Températures (°C)")
                    Spacer()
                    PinButtonView(isPinned: isPinned, action: onPinToggle)
                }
            ) {
                chartContent
                    .frame(height: 200)
            }
        } else {
            GroupBox(label:
                        HStack {
                Text("Températures (°C)")
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
            ForEach(point.temperatures, id: \.name) { temp in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Temp", temp.value)
                )
                .foregroundStyle(by: .value("Source", temp.name))
            }
        }
    }
}
