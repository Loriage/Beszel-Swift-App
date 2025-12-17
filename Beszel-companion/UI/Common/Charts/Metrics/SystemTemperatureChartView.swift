import SwiftUI
import Charts
import WidgetKit

struct SystemTemperatureChartView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    
    let xAxisFormat: Date.FormatStyle
    let dataPoints: [SystemDataPoint]
    var systemName: String? = nil
    
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}
    
    var isForWidget: Bool = false
    
    private var sensorNames: [String] {
        let allNames = dataPoints.flatMap { $0.temperatures.map(\.name) }
        return Array(Set(allNames)).sorted()
    }
    
    var body: some View {
        if !isForWidget {
            GroupBox(label: HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("chart.temperatures")
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
                chartContentWithLegend
                    .frame(height: 200)
            }
        } else {
            GroupBox(label:
                        HStack {
                Text("chart.temperatures")
                    .bold()
                Spacer()
            }
            ) {
                switch widgetFamily {
                case .systemSmall:
                    chartBody
                        .chartLegend(.hidden)
                        .chartYAxis(.hidden)
                        .chartXAxis(.hidden)
                    
                case .systemMedium, .systemLarge:
                    chartBody
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                AxisValueLabel(format: xAxisFormat, centered: true)
                            }
                        }
                    
                default:
                    chartBody
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
    
    private var chartContentWithLegend: some View {
        VStack(spacing: 8) {
            chartBody
            
            if !sensorNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(sensorNames, id: \.self) { name in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(color(for: name, in: sensorNames))
                                    .frame(width: 8, height: 8)
                                Text(name)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(height: 20)
            }
        }
    }
    
    private var chartBody: some View {
        Chart(dataPoints) { point in
            ForEach(point.temperatures, id: \.name) { temp in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Temp", temp.value)
                )
                .foregroundStyle(by: .value("Source", temp.name))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartForegroundStyleScale { name in
            color(for: name, in: sensorNames)
        }
        .chartLegend(.hidden)
        .padding(.top, 5)
        .drawingGroup()
    }
}
