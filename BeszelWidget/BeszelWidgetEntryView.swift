import SwiftUI
import WidgetKit

struct BeszelWidgetEntryView : View {
    private let languageManager = LanguageManager()
    @Environment(\.widgetFamily) private var widgetFamily
    var entry: SimpleEntry
    
    private var widgetXAxisFormat: Date.FormatStyle {
        return entry.timeRange.xAxisFormat
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            if let errorMessage = entry.errorMessage {
                ErrorView(message: errorMessage)
            }
            else if widgetFamily.isLockScreen {
                LockScreenSystemInfoView(
                    systemName: entry.systemName,
                    status: entry.status,
                    stats: entry.latestStats,
                    metric: entry.lockScreenMetric
                )
            }
            else if entry.chartType != .systemInfo && entry.dataPoints.isEmpty {
                NoDataPlaceholderView()
            }
            else {
                contentView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .environment(\.locale, Locale(identifier: languageManager.currentLanguageCode))
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch entry.chartType {
        case .systemInfo:
            if let stats = entry.latestStats {
                WidgetSystemSummaryView(
                    systemInfo: entry.systemInfo,
                    systemDetails: entry.systemDetails,
                    stats: stats,
                    systemName: entry.systemName,
                    status: entry.status
                )
            } else {
                NoDataPlaceholderView(metricName: "System Info")
            }
        case .systemCPU:
            SystemMetricChartView(
                title: "widget.chart.systemCPU.title",
                xAxisFormat: widgetXAxisFormat,
                dataPoints: entry.dataPoints,
                valueKeyPath: \.cpu,
                color: .blue,
                isForWidget: true
            )
        case .systemMemory:
            SystemMetricChartView(
                title: "widget.chart.systemMemory.title",
                xAxisFormat: widgetXAxisFormat,
                dataPoints: entry.dataPoints,
                valueKeyPath: \.memoryPercent,
                color: .green,
                isForWidget: true
            )
        case .systemTemperature:
            if entry.dataPoints.contains(where: { !$0.temperatures.isEmpty }) {
                SystemTemperatureChartView(xAxisFormat: widgetXAxisFormat, dataPoints: entry.dataPoints, isForWidget: true)
            } else {
                NoDataPlaceholderView(metricName: "widget.temperatures")
            }
        }
    }
}

struct ErrorView: View {
    let message: String
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text(LocalizedStringKey(message))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            Spacer()
        }
    }
}

struct NoDataPlaceholderView: View {
    var metricName: LocalizedStringResource? = nil
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    if let metricName = metricName {
                        Text("chart.noDataForMetric \(Text(metricName))")
                    } else {
                        Text("widget.noData")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                Spacer()
            }
            Spacer()
        }
    }
}
