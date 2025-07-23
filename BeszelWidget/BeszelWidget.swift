import WidgetKit
import SwiftUI
import Charts

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
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(LocalizedStringKey(errorMessage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    Spacer()
                }
            }
            else if entry.dataPoints.isEmpty {
                NoDataPlaceholderView()
            }
            else {
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
            if entry.dataPoints.contains(where: { !$0.temperatures.isEmpty }) {
                SystemTemperatureChartView(xAxisFormat: widgetXAxisFormat, dataPoints: entry.dataPoints, isForWidget: true)
            } else {
                NoDataPlaceholderView(metricName: "widget.temperatures")
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
}

struct Provider: AppIntentTimelineProvider {
    private let defaultChartType = WidgetChartType.systemCPU

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), chartType: defaultChartType, dataPoints: [], timeRange: .last24Hours)
    }

    func snapshot(for configuration: SelectInstanceAndChartIntent, in context: Context) async -> SimpleEntry {
        let chartType = WidgetChartType(rawValue: configuration.chart?.id ?? "") ?? defaultChartType
        return SimpleEntry(date: Date(), chartType: chartType, dataPoints: sampleDataPoints(), timeRange: .last24Hours)
    }

    func timeline(for configuration: SelectInstanceAndChartIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let instanceManager = InstanceManager.shared
        let settingsManager = SettingsManager()

        guard let selectedInstanceEntity = configuration.instance,
              let instanceID = UUID(uuidString: selectedInstanceEntity.id),
              let instanceToFetch = instanceManager.instances.first(where: { $0.id == instanceID })
        else {
            let entry = SimpleEntry(date: .now, chartType: defaultChartType, dataPoints: [], timeRange: .last24Hours, errorMessage: "widget.notConnected")
            return Timeline(entries: [entry], policy: .atEnd)
        }

        guard let selectedSystemEntity = configuration.system else {
            let entry = SimpleEntry(date: .now, chartType: defaultChartType, dataPoints: [], timeRange: .last24Hours, errorMessage: "widget.notConnected")
            return Timeline(entries: [entry], policy: .atEnd)
        }
        
        let apiService = BeszelAPIService(instance: instanceToFetch, instanceManager: instanceManager)
        let chartType = WidgetChartType(rawValue: configuration.chart?.id ?? "") ?? defaultChartType
        
        do {
            let timeFilter = settingsManager.apiFilterString ?? "1=1"
            let systemFilter = "system = '\(selectedSystemEntity.id)'"
            let finalFilter = "(\(systemFilter) && \(timeFilter))"

            let records = try await apiService.fetchSystemStats(filter: finalFilter)
            let dataPoints = DataProcessor.transformSystem(records: records)
            
            let entry = SimpleEntry(date: .now, chartType: chartType, dataPoints: dataPoints, timeRange: settingsManager.selectedTimeRange)
            let nextUpdate = Date().addingTimeInterval(15 * 60)
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        } catch {
            let entry = SimpleEntry(date: .now, chartType: chartType, dataPoints: [], timeRange: settingsManager.selectedTimeRange, errorMessage: "widget.loadingError")
            let nextUpdate = Date().addingTimeInterval(15 * 60)
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        }
    }
    
    private func sampleDataPoints() -> [SystemDataPoint] {
        var points: [SystemDataPoint] = []
        for i in 0..<10 {
            let date = Date().addingTimeInterval(TimeInterval(i * 3600))
            points.append(SystemDataPoint(date: date, cpu: Double.random(in: 20...80), memoryPercent: Double.random(in: 30...60), temperatures: []))
        }
        return points
    }
}

struct BeszelWidget: Widget {
    let kind: String = "BeszelWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectInstanceAndChartIntent.self, provider: Provider()) { entry in
            BeszelWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("widget.displayName")
        .description("widget.description")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
