import SwiftUI
import WidgetKit

struct SimpleEntry: TimelineEntry {
    let date: Date
    let chartType: WidgetChartType
    let dataPoints: [SystemDataPoint]
    let timeRange: TimeRangeOption
    var errorMessage: String? = nil
}

struct BeszelWidgetEntryView : View {
    private let languageManager = LanguageManager()
    var entry: Provider.Entry
    
    private var widgetXAxisFormat: Date.FormatStyle {
        return entry.timeRange.xAxisFormat
    }

    var body: some View {
        VStack(alignment: .leading) {
            if let errorMessage = entry.errorMessage {
                Text(LocalizedStringKey(errorMessage))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if entry.dataPoints.isEmpty {
                Text("widget.noData")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                chartView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .environment(\.locale, Locale(identifier: languageManager.currentLanguageCode))
    }

    @ViewBuilder
    private var chartView: some View {
        switch entry.chartType {
        case .systemCPU:
            SystemCpuChartView(xAxisFormat: widgetXAxisFormat, dataPoints: entry.dataPoints, isForWidget: true )
        case .systemMemory:
            SystemMemoryChartView(xAxisFormat: widgetXAxisFormat, dataPoints: entry.dataPoints, isForWidget: true)
        case .systemTemperature:
            SystemTemperatureChartView(xAxisFormat: widgetXAxisFormat, dataPoints: entry.dataPoints, isForWidget: true)
        }
    }
}
